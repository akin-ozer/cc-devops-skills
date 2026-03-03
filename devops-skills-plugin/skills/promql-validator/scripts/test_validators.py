#!/usr/bin/env python3
"""
Test suite for validate_syntax.py and check_best_practices.py.

Run from the repository root:
    python3 devops-skills-plugin/skills/promql-validator/scripts/test_validators.py

Or directly from the scripts/ directory:
    python3 test_validators.py
"""

import sys
import os
import unittest

# Allow running from either repo root or scripts/ directory.
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _SCRIPT_DIR)

from validate_syntax import PromQLSyntaxValidator
from check_best_practices import PromQLBestPracticesChecker


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def syntax(query):
    return PromQLSyntaxValidator(query).validate()


def best(query):
    return PromQLBestPracticesChecker(query).check()


def error_types(result):
    return [e['type'] for e in result['errors']]


def warning_types(result):
    return [w['type'] for w in result['warnings']]


def issue_types(result):
    return [i['type'] for i in result['issues']]


def optimization_types(result):
    return [o['type'] for o in result['optimizations']]


# ===========================================================================
# validate_syntax.py
# ===========================================================================

class TestSyntaxValid(unittest.TestCase):
    """Queries that must pass validation with no errors."""

    def test_simple_rate(self):
        r = syntax('rate(http_requests_total[5m])')
        self.assertTrue(r['valid'])
        self.assertEqual(r['status'], 'VALID')

    def test_rate_with_label_filter(self):
        r = syntax('rate(http_requests_total{job="api", status="200"}[2m])')
        self.assertTrue(r['valid'])

    def test_histogram_quantile(self):
        q = 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'
        self.assertTrue(syntax(q)['valid'])

    def test_subquery(self):
        r = syntax('max_over_time(rate(http_requests_total[5m])[30m:1m])')
        self.assertTrue(r['valid'])

    def test_offset_after_range(self):
        r = syntax('rate(http_requests_total[5m] offset 1h)')
        self.assertTrue(r['valid'])

    def test_offset_instant_vector(self):
        r = syntax('http_requests_total offset 1h')
        self.assertTrue(r['valid'])

    def test_aggregation_with_by(self):
        r = syntax('sum by (job) (rate(http_requests_total[5m]))')
        self.assertTrue(r['valid'])

    def test_predict_linear(self):
        r = syntax('predict_linear(node_filesystem_avail_bytes[1h], 4 * 3600)')
        self.assertTrue(r['valid'])

    def test_label_replace(self):
        r = syntax('label_replace(up{job="node-exporter"}, "instance", "$1", "instance", "([^:]+):.*")')
        self.assertTrue(r['valid'])

    def test_utf8_metric_with_dots(self):
        r = syntax('{"my.metric.with.dots", job="api"}')
        self.assertTrue(r['valid'])

    def test_at_modifier(self):
        r = syntax('http_requests_total{job="api"} @ 1609459200')
        self.assertTrue(r['valid'])

    def test_absent(self):
        r = syntax('absent(up{job="critical-service"})')
        self.assertTrue(r['valid'])

    def test_topk(self):
        r = syntax('topk(5, sum by (service) (rate(http_requests_total[5m])))')
        self.assertTrue(r['valid'])


class TestSyntaxErrors(unittest.TestCase):
    """Queries with structural errors that must be caught."""

    def test_empty_query(self):
        r = syntax('')
        self.assertFalse(r['valid'])
        self.assertIn('empty_query', error_types(r))

    def test_unclosed_bracket(self):
        r = syntax('rate(http_requests_total[5m)')
        self.assertFalse(r['valid'])
        self.assertIn('unclosed_bracket', error_types(r))

    def test_unmatched_closing_bracket(self):
        r = syntax('rate(http_requests_total[5m]])')
        self.assertFalse(r['valid'])
        self.assertIn('unmatched_bracket', error_types(r))

    def test_unclosed_brace(self):
        r = syntax('http_requests_total{job="api"')
        self.assertFalse(r['valid'])
        self.assertIn('unclosed_brace', error_types(r))

    def test_unclosed_paren(self):
        r = syntax('rate(http_requests_total[5m]')
        self.assertFalse(r['valid'])
        self.assertIn('unclosed_paren', error_types(r))

    def test_unclosed_string(self):
        r = syntax('http_requests_total{job="api}')
        self.assertFalse(r['valid'])
        self.assertIn('unclosed_string', error_types(r))

    def test_invalid_duration(self):
        r = syntax('rate(http_requests_total[5minutes])')
        self.assertFalse(r['valid'])
        self.assertIn('invalid_duration', error_types(r))

    def test_unknown_function(self):
        r = syntax('rte(http_requests_total[5m])')
        self.assertFalse(r['valid'])
        self.assertIn('unknown_function', error_types(r))

    def test_missing_range_vector_rate(self):
        r = syntax('rate(http_requests_total)')
        self.assertFalse(r['valid'])
        self.assertIn('missing_range_vector', error_types(r))

    def test_missing_range_vector_increase(self):
        r = syntax('increase(http_requests_total{job="api"})')
        self.assertFalse(r['valid'])
        self.assertIn('missing_range_vector', error_types(r))

    def test_missing_range_vector_irate(self):
        r = syntax('irate(http_requests_total)')
        self.assertFalse(r['valid'])
        self.assertIn('missing_range_vector', error_types(r))

    def test_misplaced_offset(self):
        r = syntax('http_requests_total offset 1h [5m]')
        self.assertFalse(r['valid'])
        self.assertIn('misplaced_offset', error_types(r))

    def test_unknown_function_with_typo_suggestion(self):
        r = syntax('rte(http_requests_total[5m])')
        self.assertIn('unknown_function', error_types(r))
        # Error message should mention a suggestion
        msg = r['errors'][0]['message']
        self.assertIn('Did you mean', msg)


class TestSyntaxWarnings(unittest.TestCase):
    """Queries that should produce warnings, not hard errors."""

    def test_empty_label_matcher(self):
        r = syntax('http_requests_total{}')
        self.assertIn('empty_label_matcher', warning_types(r))
        # Empty matcher is a warning, not an error — query is still "valid"
        self.assertTrue(r['valid'])

    def test_double_operator_in_expression(self):
        r = syntax('metric ** 2')
        self.assertIn('double_operator', warning_types(r))


class TestSyntaxFalsePositiveFixes(unittest.TestCase):
    """Regression tests for bugs that produced false warnings."""

    def test_no_double_operator_for_dash_dash_in_label_value(self):
        """-- inside a quoted label value must not trigger double_operator."""
        r = syntax('http_requests_total{path="/api--v2"}')
        self.assertTrue(r['valid'])
        self.assertNotIn('double_operator', warning_types(r))

    def test_no_double_operator_for_plus_plus_in_label_value(self):
        """++ inside a quoted label value must not trigger double_operator."""
        r = syntax('http_requests_total{version="v2++"}')
        self.assertTrue(r['valid'])
        self.assertNotIn('double_operator', warning_types(r))

    def test_no_double_operator_for_star_star_in_label_value(self):
        """** inside a quoted label value must not trigger double_operator."""
        r = syntax('metric{comment="use ** for exponents"}')
        self.assertNotIn('double_operator', warning_types(r))

    def test_double_operator_outside_string_still_detected(self):
        """A real ** outside strings must still produce the warning."""
        r = syntax('metric ** 2')
        self.assertIn('double_operator', warning_types(r))


# ===========================================================================
# check_best_practices.py
# ===========================================================================

class TestBestPracticesClean(unittest.TestCase):
    """Well-formed queries that must produce no issues."""

    def test_rate_with_labels(self):
        r = best('rate(http_requests_total{job="api", status="200"}[5m])')
        self.assertEqual(r['issues'], [])

    def test_histogram_quantile_correct(self):
        q = 'histogram_quantile(0.95, sum by (job, le) (rate(http_request_duration_seconds_bucket{job="api"}[5m])))'
        self.assertEqual(best(q)['issues'], [])

    def test_gauge_used_directly(self):
        r = best('node_memory_usage_bytes{instance="prod-1"}')
        self.assertEqual(r['issues'], [])

    def test_avg_over_time_on_gauge(self):
        r = best('avg_over_time(node_memory_usage_bytes{job="node-exporter"}[5m])')
        self.assertEqual(r['issues'], [])


class TestHighCardinality(unittest.TestCase):

    def test_bare_metric_flagged(self):
        r = best('http_requests_total')
        self.assertIn('high_cardinality', issue_types(r))

    def test_empty_label_selector_flagged(self):
        r = best('http_requests_total{}')
        self.assertIn('high_cardinality', issue_types(r))

    def test_metric_with_label_not_flagged(self):
        r = best('http_requests_total{job="api"}')
        self.assertNotIn('high_cardinality', issue_types(r))


class TestRateOnGauge(unittest.TestCase):

    def test_rate_on_bytes_gauge(self):
        r = best('rate(node_memory_usage_bytes[5m])')
        self.assertIn('rate_on_gauge', issue_types(r))

    def test_irate_on_temperature_gauge(self):
        r = best('irate(cpu_temperature_celsius[5m])')
        self.assertIn('rate_on_gauge', issue_types(r))

    def test_increase_on_bytes_gauge(self):
        r = best('increase(node_memory_usage_bytes[1h])')
        self.assertIn('rate_on_gauge', issue_types(r))

    def test_rate_on_counter_not_flagged(self):
        r = best('rate(http_requests_total[5m])')
        self.assertNotIn('rate_on_gauge', issue_types(r))


class TestMissingRate(unittest.TestCase):

    def test_bare_counter_flagged(self):
        r = best('http_requests_total{job="api"}')
        self.assertIn('missing_rate', issue_types(r))

    def test_rate_wrapped_counter_clean(self):
        r = best('rate(http_requests_total{job="api"}[5m])')
        self.assertNotIn('missing_rate', issue_types(r))

    def test_sum_count_pair_in_division_clean(self):
        """_sum/_count used as a pair for histogram average must not warn."""
        q = ('rate(http_request_duration_seconds_sum{job="api"}[5m])'
             ' / rate(http_request_duration_seconds_count{job="api"}[5m])')
        self.assertNotIn('missing_rate', issue_types(best(q)))

    def test_orphan_sum_metric_flagged(self):
        r = best('http_request_duration_seconds_sum{job="api"}')
        self.assertIn('missing_rate', issue_types(r))


class TestMissingRateFalsePositiveFix(unittest.TestCase):
    """Regression tests for the counter-name-in-label-value false positive."""

    def test_counter_name_in_label_value_not_flagged(self):
        """http_requests_total appearing as a label VALUE must not produce missing_rate."""
        r = best('other_metric_total{label="http_requests_total"}')
        issues = issue_types(r)
        # Exactly ONE missing_rate for the actual bare counter (other_metric_total)
        self.assertEqual(issues.count('missing_rate'), 1)
        # Confirm it's for the outer metric, not the label value
        msg = r['issues'][0]['message']
        self.assertIn('other_metric_total', msg)
        self.assertNotIn('http_requests_total', msg)

    def test_bucket_name_in_label_value_not_flagged(self):
        """_bucket suffix in a label value must not trigger missing_rate."""
        r = best('config_metric{source="http_request_duration_seconds_bucket"}')
        # config_metric has no counter suffix, so missing_rate should not fire at all
        self.assertNotIn('missing_rate', issue_types(r))

    def test_counter_name_in_label_value_with_rate_wrapper(self):
        """A well-formed rate() query with a counter name in a label value is fully clean."""
        r = best('rate(http_requests_total{label="some_counter_total"}[5m])')
        self.assertNotIn('missing_rate', issue_types(r))


class TestAveragingQuantiles(unittest.TestCase):

    def test_avg_on_quantile_flagged(self):
        r = best('avg(http_request_duration_seconds{quantile="0.95"})')
        self.assertIn('averaging_quantiles', issue_types(r))

    def test_sum_on_quantile_flagged(self):
        """sum() on pre-calculated quantile is equally invalid — must be detected."""
        r = best('sum(http_request_duration_seconds{quantile="0.95"})')
        self.assertIn('averaging_quantiles', issue_types(r))

    def test_min_on_quantile_flagged(self):
        r = best('min(http_request_duration_seconds{quantile="0.99"})')
        self.assertIn('averaging_quantiles', issue_types(r))

    def test_max_on_quantile_flagged(self):
        r = best('max(http_request_duration_seconds{quantile="0.50"})')
        self.assertIn('averaging_quantiles', issue_types(r))

    def test_stddev_on_quantile_flagged(self):
        r = best('stddev(response_time_seconds{quantile="0.99"})')
        self.assertIn('averaging_quantiles', issue_types(r))

    def test_avg_without_quantile_not_flagged(self):
        """avg() on a gauge must NOT trigger averaging_quantiles."""
        r = best('avg(node_memory_usage_bytes)')
        self.assertNotIn('averaging_quantiles', issue_types(r))

    def test_correct_histogram_quantile_not_flagged(self):
        """histogram_quantile() with buckets must never trigger averaging_quantiles."""
        q = 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'
        self.assertNotIn('averaging_quantiles', issue_types(best(q)))


class TestIrateRange(unittest.TestCase):

    def test_irate_long_range_flagged(self):
        r = best('irate(http_requests_total[1h])')
        self.assertIn('irate_long_range', issue_types(r))

    def test_irate_short_range_clean(self):
        r = best('irate(http_requests_total{job="api"}[2m])')
        self.assertNotIn('irate_long_range', issue_types(r))


class TestRateRange(unittest.TestCase):

    def test_rate_short_range_flagged(self):
        r = best('rate(http_requests_total{job="api"}[30s])')
        self.assertIn('rate_short_range', issue_types(r))

    def test_rate_acceptable_range_clean(self):
        r = best('rate(http_requests_total{job="api"}[2m])')
        self.assertNotIn('rate_short_range', issue_types(r))


class TestExpensiveSubquery(unittest.TestCase):

    def test_long_subquery_flagged(self):
        r = best('rate(http_requests_total[5m])[95d:1m]')
        self.assertIn('expensive_subquery', issue_types(r))

    def test_reasonable_subquery_clean(self):
        r = best('max_over_time(rate(http_requests_total{job="api"}[5m])[30m:1m])')
        self.assertNotIn('expensive_subquery', issue_types(r))


class TestHistogramUsage(unittest.TestCase):

    def test_histogram_quantile_without_rate_flagged(self):
        q = 'histogram_quantile(0.95, sum by (le) (http_request_duration_seconds_bucket))'
        self.assertIn('histogram_missing_rate', issue_types(best(q)))

    def test_histogram_quantile_missing_le_flagged(self):
        q = 'histogram_quantile(0.95, sum by (job) (rate(http_request_duration_seconds_bucket[5m])))'
        self.assertIn('histogram_missing_le', issue_types(best(q)))

    def test_correct_histogram_quantile_clean(self):
        q = 'histogram_quantile(0.95, sum by (job, le) (rate(http_request_duration_seconds_bucket{job="api"}[5m])))'
        self.assertNotIn('histogram_missing_rate', issue_types(best(q)))
        self.assertNotIn('histogram_missing_le', issue_types(best(q)))


class TestDeprecatedFunctions(unittest.TestCase):

    def test_holt_winters_flagged(self):
        r = best('holt_winters(http_requests_total[5m], 0.1, 0.3)')
        self.assertIn('deprecated_function', issue_types(r))


class TestRegexOveruse(unittest.TestCase):

    def test_exact_string_with_regex_operator_flagged_as_optimization(self):
        """=~"200" can be expressed as ="200" — should appear in optimizations."""
        r = best('rate(http_requests_total{status=~"200"}[5m])')
        self.assertIn('regex_to_exact', optimization_types(r))

    def test_real_regex_not_flagged(self):
        """=~"5.." is a real regex pattern and must not be flagged."""
        r = best('rate(http_requests_total{status=~"5.."}[5m])')
        self.assertNotIn('regex_to_exact', optimization_types(r))


class TestVectorMatching(unittest.TestCase):

    def test_info_metric_join_missing_group_left_flagged(self):
        q = 'rate(http_requests_total[5m]) * on (job, instance) service_info'
        self.assertIn('info_metric_missing_group', issue_types(best(q)))

    def test_group_left_without_on_flagged(self):
        q = 'metric_a * group_left() metric_b'
        self.assertIn('group_without_matching', issue_types(best(q)))


if __name__ == '__main__':
    unittest.main(verbosity=2)
