#!/usr/bin/env python3
"""
Tests for generate_config.py

Run with:
    python3 -m unittest scripts/test_generate_config.py -v
or:
    python3 -m pytest scripts/test_generate_config.py -v
"""

import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from generate_config import LokiConfigGenerator  # noqa: E402

GENERATOR = SCRIPT_DIR / "generate_config.py"

ALL_MODES = ["monolithic", "simple-scalable", "microservices"]
ALL_STORAGES = ["filesystem", "s3", "gcs", "azure"]


class TestAllCombinationsGenerate(unittest.TestCase):
    """Every mode × storage combo must generate a non-empty valid YAML."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_all_mode_storage_combos_produce_valid_yaml(self):
        for mode in ALL_MODES:
            for storage in ALL_STORAGES:
                with self.subTest(mode=mode, storage=storage):
                    config = self.gen.generate(mode, storage)
                    self.assertIsInstance(config, str)
                    self.assertGreater(len(config.strip()), 0)
                    doc = yaml.safe_load(config)
                    self.assertIsNotNone(doc, f"{mode}+{storage} returned empty YAML doc")

    def test_unknown_mode_raises_value_error(self):
        with self.assertRaises(ValueError):
            self.gen.generate("invalid-mode", "s3")

    def test_unknown_storage_raises_value_error(self):
        with self.assertRaises(ValueError):
            self.gen.generate("monolithic", "invalid-storage")


class TestSchemaConfig(unittest.TestCase):
    """Schema must always use tsdb + v13 for all generated configs."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def _schema_entry(self, config: str) -> dict:
        doc = yaml.safe_load(config)
        return doc["schema_config"]["configs"][0]

    def test_all_combos_use_tsdb_v13(self):
        for mode in ALL_MODES:
            for storage in ["s3", "gcs", "azure", "filesystem"]:
                with self.subTest(mode=mode, storage=storage):
                    config = self.gen.generate(mode, storage)
                    entry = self._schema_entry(config)
                    self.assertEqual(entry["store"], "tsdb")
                    self.assertEqual(entry["schema"], "v13")
                    self.assertEqual(entry["index"]["period"], "24h")

    def test_schema_object_store_matches_storage_backend(self):
        mapping = {"s3": "s3", "gcs": "gcs", "azure": "azure", "filesystem": "filesystem"}
        for storage, expected in mapping.items():
            with self.subTest(storage=storage):
                config = self.gen.generate("simple-scalable", storage)
                entry = self._schema_entry(config)
                self.assertEqual(entry["object_store"], expected)


class TestAuthDefaults(unittest.TestCase):
    """auth_enabled defaults differ by deployment mode."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_monolithic_defaults_auth_disabled(self):
        doc = yaml.safe_load(self.gen.generate("monolithic", "filesystem"))
        self.assertFalse(doc["auth_enabled"])

    def test_simple_scalable_defaults_auth_enabled(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3"))
        self.assertTrue(doc["auth_enabled"])

    def test_microservices_defaults_auth_enabled(self):
        doc = yaml.safe_load(self.gen.generate("microservices", "s3"))
        self.assertTrue(doc["auth_enabled"])

    def test_auth_enabled_can_be_overridden(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3", auth_enabled=False))
        self.assertFalse(doc["auth_enabled"])

    def test_auth_disabled_can_be_overridden_for_monolithic(self):
        doc = yaml.safe_load(self.gen.generate("monolithic", "filesystem", auth_enabled=True))
        self.assertTrue(doc["auth_enabled"])


class TestFilesystemStorageMonolithic(unittest.TestCase):
    """Monolithic + filesystem must use inmemory ring and replication_factor=1."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_uses_inmemory_ring(self):
        doc = yaml.safe_load(self.gen.generate("monolithic", "filesystem"))
        ring_store = doc["common"]["ring"]["kvstore"]["store"]
        self.assertEqual(ring_store, "inmemory")

    def test_replication_factor_is_1(self):
        doc = yaml.safe_load(self.gen.generate("monolithic", "filesystem"))
        self.assertEqual(doc["common"]["replication_factor"], 1)

    def test_no_memberlist_block(self):
        config = self.gen.generate("monolithic", "filesystem")
        self.assertNotIn("memberlist:", config)


class TestMemberlistRing(unittest.TestCase):
    """Simple-scalable must use memberlist ring and produce a memberlist join block."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_simple_scalable_uses_memberlist(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3"))
        ring_store = doc["common"]["ring"]["kvstore"]["store"]
        self.assertEqual(ring_store, "memberlist")

    def test_memberlist_join_members_present(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3"))
        self.assertIn("memberlist", doc)
        self.assertIn("join_members", doc["memberlist"])

    def test_microservices_uses_consul(self):
        doc = yaml.safe_load(self.gen.generate("microservices", "s3"))
        ring_store = doc["common"]["ring"]["kvstore"]["store"]
        self.assertEqual(ring_store, "consul")

    def test_microservices_no_memberlist_block(self):
        config = self.gen.generate("microservices", "s3")
        self.assertNotIn("memberlist:", config)


class TestLimitsConfig(unittest.TestCase):
    """Limits section must be present and respect custom parameters."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_limits_config_present(self):
        for mode in ALL_MODES:
            with self.subTest(mode=mode):
                doc = yaml.safe_load(self.gen.generate(mode, "s3"))
                self.assertIn("limits_config", doc)

    def test_custom_retention_days(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3", retention_days=60))
        self.assertEqual(doc["limits_config"]["retention_period"], "60d")

    def test_ingestion_burst_is_double_rate(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3", ingestion_rate_mb=20))
        lc = doc["limits_config"]
        self.assertEqual(lc["ingestion_rate_mb"], 20)
        self.assertEqual(lc["ingestion_burst_size_mb"], 40)

    def test_structured_metadata_always_allowed(self):
        for mode in ALL_MODES:
            with self.subTest(mode=mode):
                doc = yaml.safe_load(self.gen.generate(mode, "s3"))
                self.assertTrue(doc["limits_config"]["allow_structured_metadata"])

    def test_volume_enabled(self):
        for mode in ALL_MODES:
            with self.subTest(mode=mode):
                doc = yaml.safe_load(self.gen.generate(mode, "s3"))
                self.assertTrue(doc["limits_config"]["volume_enabled"])


class TestPatternIngester(unittest.TestCase):
    """Pattern ingester enabled by default, can be disabled."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_pattern_ingester_enabled_by_default(self):
        for mode in ALL_MODES:
            with self.subTest(mode=mode):
                doc = yaml.safe_load(self.gen.generate(mode, "s3"))
                # Microservices does not emit pattern_ingester block
                if mode != "microservices":
                    self.assertTrue(doc.get("pattern_ingester", {}).get("enabled", False))

    def test_pattern_ingester_can_be_disabled(self):
        config = self.gen.generate("monolithic", "filesystem", pattern_ingester=False)
        self.assertNotIn("pattern_ingester:", config)


class TestOtlpConfig(unittest.TestCase):
    """OTLP config: k8s.pod.name must never be an index_label (high cardinality)."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def _otlp_attrs(self, config: str):
        doc = yaml.safe_load(config)
        otlp = doc.get("limits_config", {}).get("otlp_config", {})
        index_labels, structured_meta = [], []
        for entry in otlp.get("resource_attributes", {}).get("attributes_config", []):
            if entry["action"] == "index_label":
                index_labels += entry["attributes"]
            elif entry["action"] == "structured_metadata":
                structured_meta += entry["attributes"]
        return index_labels, structured_meta

    def test_otlp_not_in_output_by_default(self):
        config = self.gen.generate("simple-scalable", "s3")
        doc = yaml.safe_load(config)
        self.assertNotIn("otlp_config", doc.get("limits_config", {}))

    def test_otlp_generated_when_enabled(self):
        config = self.gen.generate("simple-scalable", "s3", otlp_enabled=True)
        doc = yaml.safe_load(config)
        self.assertIn("otlp_config", doc["limits_config"])

    def test_high_cardinality_attrs_not_in_index_labels(self):
        config = self.gen.generate("simple-scalable", "s3", otlp_enabled=True)
        index_labels, _ = self._otlp_attrs(config)
        self.assertNotIn("k8s.pod.name", index_labels, "k8s.pod.name must not be an index_label")
        self.assertNotIn("service.instance.id", index_labels, "service.instance.id must not be an index_label")

    def test_high_cardinality_attrs_in_structured_metadata(self):
        config = self.gen.generate("simple-scalable", "s3", otlp_enabled=True)
        _, structured_meta = self._otlp_attrs(config)
        self.assertIn("k8s.pod.name", structured_meta)
        self.assertIn("service.instance.id", structured_meta)

    def test_otlp_and_time_sharding_both_in_limits(self):
        config = self.gen.generate("simple-scalable", "s3", otlp_enabled=True, time_sharding=True)
        doc = yaml.safe_load(config)
        lc = doc["limits_config"]
        self.assertIn("otlp_config", lc)
        self.assertIn("shard_streams", lc)
        self.assertTrue(lc["shard_streams"]["time_sharding_enabled"])


class TestZoneAwareness(unittest.TestCase):
    """Zone awareness must appear in both storage (common block) and ingester."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_zone_awareness_in_ingester(self):
        config = self.gen.generate("simple-scalable", "s3", zone_awareness=True)
        self.assertIn("zone_awareness_enabled: true", config)

    def test_zone_awareness_in_common_block(self):
        config = self.gen.generate("simple-scalable", "s3", zone_awareness=True)
        self.assertIn("instance_availability_zone", config)

    def test_zone_awareness_absent_when_not_requested(self):
        config = self.gen.generate("simple-scalable", "s3", zone_awareness=False)
        self.assertNotIn("zone_awareness_enabled", config)
        self.assertNotIn("instance_availability_zone", config)

    def test_microservices_zone_awareness(self):
        config = self.gen.generate("microservices", "s3", zone_awareness=True)
        self.assertIn("zone_awareness_enabled: true", config)


class TestCompactorConfig(unittest.TestCase):
    """Compactor must be present and support Loki 3.5+ / 3.6+ features."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_compactor_present_all_modes(self):
        for mode in ALL_MODES:
            with self.subTest(mode=mode):
                doc = yaml.safe_load(self.gen.generate(mode, "s3"))
                self.assertIn("compactor", doc)

    def test_retention_enabled(self):
        doc = yaml.safe_load(self.gen.generate("simple-scalable", "s3"))
        self.assertTrue(doc["compactor"]["retention_enabled"])

    def test_delete_request_store_sqlite(self):
        config = self.gen.generate("simple-scalable", "s3", delete_request_store="sqlite")
        self.assertIn("delete_request_store: sqlite", config)

    def test_delete_request_store_absent_by_default(self):
        config = self.gen.generate("simple-scalable", "s3")
        self.assertNotIn("delete_request_store:", config)

    def test_horizontal_compactor_main(self):
        config = self.gen.generate("simple-scalable", "s3", horizontal_compactor="main")
        self.assertIn("horizontal_scaling_mode: main", config)

    def test_horizontal_compactor_worker(self):
        config = self.gen.generate("simple-scalable", "s3", horizontal_compactor="worker")
        self.assertIn("horizontal_scaling_mode: worker", config)

    def test_horizontal_compactor_disabled_by_default(self):
        config = self.gen.generate("simple-scalable", "s3")
        self.assertNotIn("horizontal_scaling_mode", config)


class TestThanosStorage(unittest.TestCase):
    """Thanos storage clients (Loki 3.4+) for S3, GCS, and Azure."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_thanos_s3_generates_storage_config(self):
        config = self.gen.generate("simple-scalable", "s3", thanos_storage=True, bucket="my-bucket")
        doc = yaml.safe_load(config)
        sc = doc["storage_config"]
        self.assertTrue(sc["use_thanos_objstore"])
        self.assertEqual(sc["object_store"]["s3"]["bucket_name"], "my-bucket")

    def test_thanos_gcs_generates_storage_config(self):
        config = self.gen.generate("simple-scalable", "gcs", thanos_storage=True, bucket="my-gcs-bucket")
        doc = yaml.safe_load(config)
        sc = doc["storage_config"]
        self.assertTrue(sc["use_thanos_objstore"])
        self.assertEqual(sc["object_store"]["gcs"]["bucket_name"], "my-gcs-bucket")

    def test_thanos_azure_generates_storage_config(self):
        config = self.gen.generate("simple-scalable", "azure", thanos_storage=True, container="my-container")
        doc = yaml.safe_load(config)
        sc = doc["storage_config"]
        self.assertTrue(sc["use_thanos_objstore"])
        self.assertEqual(sc["object_store"]["azure"]["container_name"], "my-container")

    def test_thanos_filesystem_falls_back_with_warning(self):
        """Thanos does not support filesystem; generator falls back and warns on stderr."""
        with contextlib.redirect_stderr(io.StringIO()) as stderr:
            config = self.gen.generate("simple-scalable", "filesystem", thanos_storage=True)
        self.assertNotIn("use_thanos_objstore", config)
        self.assertIn("chunks_directory", config)
        self.assertIn("ignored", stderr.getvalue().lower())

    def test_thanos_filesystem_microservices_warns(self):
        with contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.gen.generate("microservices", "filesystem", thanos_storage=True)
        self.assertIn("ignored", stderr.getvalue().lower())

    def test_thanos_with_microservices(self):
        config = self.gen.generate("microservices", "s3", thanos_storage=True, bucket="ms-bucket")
        doc = yaml.safe_load(config)
        self.assertTrue(doc["storage_config"]["use_thanos_objstore"])


class TestLimitsDryRun(unittest.TestCase):
    """limits_dry_run handling differs by mode."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_microservices_dry_run_via_api(self):
        config = self.gen.generate("microservices", "s3", limits_dry_run=True)
        self.assertIn("ingest_limits_dry_run_enabled: true", config)
        # Must produce exactly one distributor: block
        self.assertEqual(config.count("distributor:"), 1)

    def test_simple_scalable_dry_run_applied_via_api(self):
        config_with = self.gen.generate("simple-scalable", "s3", limits_dry_run=True)
        config_without = self.gen.generate("simple-scalable", "s3", limits_dry_run=False)
        self.assertIn("ingest_limits_dry_run_enabled: true", config_with)
        self.assertNotIn("ingest_limits_dry_run_enabled", config_without)

    def test_monolithic_dry_run_applied_via_api(self):
        config = self.gen.generate("monolithic", "filesystem", limits_dry_run=True)
        self.assertIn("ingest_limits_dry_run_enabled: true", config)

    def test_monolithic_dry_run_absent_by_default(self):
        config = self.gen.generate("monolithic", "filesystem")
        self.assertNotIn("ingest_limits_dry_run_enabled", config)

    def test_cli_simple_scalable_dry_run_is_applied(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            result = subprocess.run(
                [sys.executable, str(GENERATOR),
                 "--mode", "simple-scalable", "--storage", "s3", "--limits-dry-run",
                 "--output", tmp.name],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0)
            content = Path(tmp.name).read_text()
        self.assertIn("ingest_limits_dry_run_enabled: true", content)
        # Only one distributor: block — no double-append
        self.assertEqual(content.count("distributor:"), 1)


class TestRulerConfig(unittest.TestCase):
    """Ruler config generation for simple-scalable and microservices."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_ruler_not_in_output_by_default(self):
        config = self.gen.generate("simple-scalable", "s3")
        self.assertNotIn("ruler:", config)

    def test_ruler_enabled_generates_ruler_config_via_api(self):
        config_with = self.gen.generate("simple-scalable", "s3", ruler_enabled=True)
        config_without = self.gen.generate("simple-scalable", "s3", ruler_enabled=False)
        self.assertIn("ruler:", config_with)
        self.assertNotIn("ruler:", config_without)

    def test_microservices_ruler_via_api(self):
        config = self.gen.generate("microservices", "s3", ruler_enabled=True)
        self.assertIn("ruler:", config)
        # Microservices uses consul ring for the ruler
        self.assertIn("store: consul", config)

    def test_ruler_config_method_generates_correct_structure(self):
        config = self.gen._generate_ruler_config(storage_type="s3", bucket="ruler-bucket")
        self.assertIn("ruler:", config)
        self.assertIn("enable_api: true", config)
        self.assertIn("enable_sharding: true", config)
        self.assertIn("enable_alertmanager_v2: true", config)

    def test_ruler_thanos_storage_uses_ruler_storage_block(self):
        config = self.gen._generate_ruler_config(
            storage_type="s3", bucket="ruler-bucket", thanos_storage=True
        )
        self.assertIn("ruler_storage:", config)
        self.assertNotIn("ruler:\n  storage:", config)

    def test_ruler_non_thanos_uses_inline_storage(self):
        config = self.gen._generate_ruler_config(
            storage_type="s3", bucket="ruler-bucket", thanos_storage=False
        )
        self.assertNotIn("ruler_storage:", config)
        self.assertIn("ruler:\n  storage:", config)

    def test_ruler_remote_write(self):
        config = self.gen._generate_ruler_config(
            storage_type="s3", bucket="ruler-bucket",
            enable_remote_write=True, remote_write_url="http://prom:9090/api/v1/write",
        )
        self.assertIn("remote_write:", config)
        self.assertIn("http://prom:9090/api/v1/write", config)

    def test_cli_ruler_simple_scalable(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            result = subprocess.run(
                [sys.executable, str(GENERATOR),
                 "--mode", "simple-scalable", "--storage", "s3", "--ruler",
                 "--output", tmp.name],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            content = Path(tmp.name).read_text()
        self.assertIn("ruler:", content)
        # Exactly one ruler: block — no double-append from CLI + generate()
        self.assertEqual(content.count("\nruler:"), 1)

    def test_cli_ruler_monolithic_errors(self):
        result = subprocess.run(
            [sys.executable, str(GENERATOR),
             "--mode", "monolithic", "--storage", "filesystem", "--ruler",
             "--output", "/tmp/unused.yaml"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)


class TestBuildRingKvstore(unittest.TestCase):
    """_build_ring_kvstore_config should produce correct YAML fragments."""

    def setUp(self):
        self.gen = LokiConfigGenerator()

    def test_memberlist(self):
        block = self.gen._build_ring_kvstore_config(ring_store="memberlist")
        self.assertIn("store: memberlist", block)

    def test_consul(self):
        block = self.gen._build_ring_kvstore_config(ring_store="consul", consul_host="consul:8500")
        self.assertIn("store: consul", block)
        self.assertIn("host: consul:8500", block)

    def test_inmemory(self):
        block = self.gen._build_ring_kvstore_config(ring_store="inmemory")
        self.assertIn("store: inmemory", block)

    def test_inmemory_with_instance_addr(self):
        block = self.gen._build_ring_kvstore_config(ring_store="inmemory", include_instance_addr=True)
        self.assertIn("instance_addr: 127.0.0.1", block)

    def test_unsupported_store_raises(self):
        with self.assertRaises(ValueError):
            self.gen._build_ring_kvstore_config(ring_store="etcd")


class TestCLI(unittest.TestCase):
    """Smoke tests for the CLI entry point."""

    def _run(self, *args, expect_success=True):
        result = subprocess.run(
            [sys.executable, str(GENERATOR), *args],
            capture_output=True,
            text=True,
        )
        if expect_success:
            self.assertEqual(
                result.returncode, 0,
                f"CLI failed.\nstdout: {result.stdout}\nstderr: {result.stderr}",
            )
        return result

    def test_help(self):
        result = self._run("--help")
        self.assertIn("--mode", result.stdout)
        self.assertIn("--storage", result.stdout)

    def test_monolithic_filesystem(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "monolithic", "--storage", "filesystem",
                      "--no-auth-enabled", "--output", tmp.name)
            doc = yaml.safe_load(Path(tmp.name).read_text())
        self.assertFalse(doc["auth_enabled"])
        self.assertEqual(doc["schema_config"]["configs"][0]["store"], "tsdb")

    def test_simple_scalable_s3(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--bucket", "test-bucket", "--region", "eu-west-1", "--output", tmp.name)
            content = Path(tmp.name).read_text()
            doc = yaml.safe_load(content)
        self.assertTrue(doc["auth_enabled"])
        self.assertIn("test-bucket", content)
        self.assertIn("eu-west-1", content)

    def test_microservices_gcs(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "microservices", "--storage", "gcs",
                      "--bucket", "loki-gcs", "--output", tmp.name)
            doc = yaml.safe_load(Path(tmp.name).read_text())
        self.assertIn("query_scheduler", doc)
        self.assertIn("index_gateway", doc)

    def test_invalid_mode_exits_nonzero(self):
        result = self._run("--mode", "invalid", "--storage", "s3",
                           "--output", "/tmp/unused.yaml", expect_success=False)
        self.assertNotEqual(result.returncode, 0)

    def test_invalid_storage_exits_nonzero(self):
        result = self._run("--mode", "monolithic", "--storage", "invalid",
                           "--output", "/tmp/unused.yaml", expect_success=False)
        self.assertNotEqual(result.returncode, 0)

    def test_zone_awareness_flag(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--zone-awareness", "--output", tmp.name)
            content = Path(tmp.name).read_text()
        self.assertIn("zone_awareness_enabled: true", content)
        self.assertIn("instance_availability_zone", content)

    def test_otlp_enabled_flag(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--otlp-enabled", "--output", tmp.name)
            doc = yaml.safe_load(Path(tmp.name).read_text())
        self.assertIn("otlp_config", doc["limits_config"])

    def test_thanos_storage_flag(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--thanos-storage", "--bucket", "thanos-bucket", "--output", tmp.name)
            doc = yaml.safe_load(Path(tmp.name).read_text())
        self.assertTrue(doc["storage_config"]["use_thanos_objstore"])

    def test_time_sharding_flag(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--time-sharding", "--output", tmp.name)
            doc = yaml.safe_load(Path(tmp.name).read_text())
        self.assertTrue(doc["limits_config"]["shard_streams"]["time_sharding_enabled"])

    def test_horizontal_compactor_main(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            self._run("--mode", "simple-scalable", "--storage", "s3",
                      "--horizontal-compactor", "main", "--output", tmp.name)
            content = Path(tmp.name).read_text()
        self.assertIn("horizontal_scaling_mode: main", content)

    def test_mutually_exclusive_auth_flags(self):
        result = self._run("--mode", "monolithic", "--storage", "filesystem",
                           "--auth-enabled", "--no-auth-enabled",
                           "--output", "/tmp/unused.yaml", expect_success=False)
        self.assertNotEqual(result.returncode, 0)

    def test_output_file_created(self):
        with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as tmp:
            path = Path(tmp.name)
        self._run("--mode", "monolithic", "--storage", "filesystem", "--output", str(path))
        self.assertTrue(path.exists())
        self.assertGreater(path.stat().st_size, 0)


if __name__ == "__main__":
    unittest.main()
