#!/usr/bin/env python3
"""
PromQL Best Practices Checker

Detects anti-patterns, performance issues, and optimization opportunities in PromQL queries.
Provides actionable suggestions for improving query efficiency and correctness.
"""

import re
import sys
import json
from typing import Dict, List, Tuple, Optional


class PromQLBestPracticesChecker:
    """Checks PromQL queries for best practices and anti-patterns"""

    # Metric name patterns
    COUNTER_SUFFIXES = ['_total', '_count', '_sum', '_bucket']
    # Expanded gauge patterns based on common naming conventions
    # See: https://prometheus.io/docs/practices/naming/
    GAUGE_PATTERNS = [
        '_bytes',           # Memory, disk sizes (when not _bytes_total)
        '_ratio',           # Ratios like cache_hit_ratio
        '_usage',           # Resource usage metrics
        '_percent',         # Percentage values
        '_gauge',           # Explicitly named gauges
        '_celsius',         # Temperature metrics
        '_fahrenheit',      # Temperature metrics
        '_temperature',     # Temperature metrics
        '_info',            # Info metrics (always 1, with labels)
        '_size',            # Size measurements
        '_current',         # Current values (e.g., connections_current)
        '_limit',           # Limit values
        '_available',       # Available resources
        '_free',            # Free resources
        '_used',            # Used resources (when not a counter)
        '_utilization',     # Utilization percentages
        '_capacity',        # Capacity values
        '_level',           # Level measurements
    ]

    # Rate functions
    RATE_FUNCTIONS = ['rate', 'irate', 'increase', 'delta', 'idelta']

    # Native histogram functions (Prometheus 2.40+/3.0)
    NATIVE_HISTOGRAM_FUNCTIONS = [
        'histogram_avg', 'histogram_stddev', 'histogram_stdvar',
        'histogram_count', 'histogram_sum', 'histogram_fraction'
    ]

    def __init__(self, query: str):
        self.query = query.strip()
        self.issues: List[Dict] = []
        self.suggestions: List[Dict] = []
        self.optimizations: List[Dict] = []

    def check(self) -> Dict:
        """
        Run all best practice checks

        Returns:
            Dict containing check results
        """
        if not self.query:
            return self._build_result()

        # Check for anti-patterns
        self._check_high_cardinality()
        self._check_regex_overuse()
        self._check_missing_rate_on_counters()
        self._check_rate_on_gauges()
        self._check_averaging_quantiles()
        self._check_subquery_performance()
        self._check_irate_range()
        self._check_rate_range()
        self._check_unbounded_queries()
        self._check_aggregation_best_practices()
        self._check_recording_rule_opportunity()
        self._check_label_matcher_efficiency()
        self._check_histogram_usage()
        # Prometheus 3.0+ and additional checks
        self._check_deprecated_functions()
        self._check_predict_linear_range()
        self._check_division_by_zero_risk()
        self._check_changes_resets_alerting()
        self._check_dimensional_metric_names()
        # New checks based on documentation research
        self._check_absent_with_aggregation()
        self._check_vector_matching()
        self._check_native_histogram_usage()
        # Design pattern checks
        self._check_mixed_metric_types()

        return self._build_result()

    def _check_high_cardinality(self):
        """Check for queries that might match too many time series"""
        # Check for metric selectors with no or very few label filters
        # Pattern: metric_name or metric_name{}
        if re.search(r'\b[a-zA-Z_:][a-zA-Z0-9_:]*\s*\{\s*\}', self.query):
            self.issues.append({
                'type': 'high_cardinality',
                'message': 'Query uses empty label matcher {} which may match many time series',
                'severity': 'warning',
                'recommendation': 'Add specific label filters like {job="...", instance="..."} to reduce cardinality'
            })

        # Check for bare metric names without selectors
        # First, remove content inside {...} blocks and strings to avoid matching label names
        query_without_selectors = self._strip_label_selectors_and_strings(self.query)

        metric_pattern = r'\b([a-zA-Z_:][a-zA-Z0-9_:]*)\b(?!\s*[{\(])'
        metrics_without_selectors = re.findall(metric_pattern, query_without_selectors)

        # Filter out function names, keywords, and PromQL reserved words
        reserved_words = {
            # Aggregation operators
            'sum', 'avg', 'min', 'max', 'count', 'stddev', 'stdvar', 'group',
            'topk', 'bottomk', 'quantile', 'count_values', 'limitk', 'limit_ratio',
            # Functions
            'rate', 'irate', 'increase', 'delta', 'idelta', 'deriv', 'predict_linear',
            'histogram_quantile', 'histogram_count', 'histogram_sum', 'histogram_fraction',
            'histogram_avg', 'histogram_stddev', 'histogram_stdvar',
            'abs', 'ceil', 'floor', 'round', 'sqrt', 'exp', 'ln', 'log2', 'log10',
            'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
            'deg', 'rad', 'sgn', 'clamp', 'clamp_max', 'clamp_min', 'pi',
            'timestamp', 'time', 'minute', 'hour', 'day_of_month', 'day_of_week',
            'days_in_month', 'month', 'year',
            'label_replace', 'label_join', 'vector', 'scalar',
            'changes', 'resets', 'absent', 'absent_over_time', 'present_over_time',
            'avg_over_time', 'min_over_time', 'max_over_time', 'sum_over_time',
            'count_over_time', 'quantile_over_time', 'stddev_over_time', 'stdvar_over_time',
            'last_over_time', 'mad_over_time', 'sort', 'sort_desc', 'sort_by_label',
            'sort_by_label_desc', 'holt_winters', 'double_exponential_smoothing', 'info',
            # Keywords and operators
            'by', 'without', 'and', 'or', 'unless', 'on', 'ignoring',
            'group_left', 'group_right', 'bool', 'offset', 'start', 'end',
            # Constants
            'inf', 'nan'
        }

        for metric in metrics_without_selectors:
            if metric.lower() not in reserved_words:
                # Check if this metric has label filters in the ORIGINAL query
                # A metric with filters looks like: metric_name{label="value"}
                # We need to check if this metric is followed by a non-empty {...} block
                escaped_metric = re.escape(metric)
                has_filters = re.search(
                    rf'\b{escaped_metric}\s*\{{\s*[^}}]+\s*\}}',
                    self.query
                )
                if not has_filters:
                    self.issues.append({
                        'type': 'high_cardinality',
                        'message': f'Metric "{metric}" used without label filters',
                        'severity': 'warning',
                        'recommendation': f'Add label filters: {metric}{{job="...", instance="..."}}'
                    })

    def _strip_label_selectors_and_strings(self, query: str) -> str:
        """
        Remove content inside {...} label selectors, quoted strings, and grouping clauses.
        This prevents label names from being misidentified as metric names.

        Also strips content from:
        - by (...) clauses
        - without (...) clauses
        - on (...) clauses
        - ignoring (...) clauses
        - group_left(...) clauses
        - group_right(...) clauses
        """
        # First, strip grouping clauses (by, without, on, ignoring, group_left, group_right)
        # These contain label names, not metric names
        query = re.sub(r'\b(by|without|on|ignoring|group_left|group_right)\s*\([^)]*\)', r'\1 ( )', query)

        result = []
        depth = 0
        in_string = False
        escape_next = False
        i = 0

        while i < len(query):
            char = query[i]

            if escape_next:
                escape_next = False
                i += 1
                continue

            if char == '\\':
                escape_next = True
                i += 1
                continue

            if char == '"':
                in_string = not in_string
                i += 1
                continue

            if in_string:
                i += 1
                continue

            if char == '{':
                depth += 1
                result.append(' ')  # Replace with space to preserve word boundaries
                i += 1
                continue

            if char == '}':
                depth = max(0, depth - 1)
                result.append(' ')
                i += 1
                continue

            if depth == 0:
                result.append(char)
            else:
                # Inside {...}, replace with space to maintain positions
                result.append(' ')

            i += 1

        return ''.join(result)

    def _check_regex_overuse(self):
        """Check for regex matchers that could be exact matches"""
        # Find regex matchers =~ and !~
        regex_matchers = re.findall(r'([a-zA-Z_][a-zA-Z0-9_]*)\s*=~\s*"([^"]+)"', self.query)

        # Regex metacharacters that indicate an actual regex pattern (not just a literal string)
        # Note: . is a metacharacter meaning "any character", so "5.." is a regex pattern
        regex_metacharacters = r'[\.\*\+\?\^\$\[\]\(\)\|\\]'

        for label, pattern in regex_matchers:
            # Check if the pattern contains any regex metacharacters
            # If it does, it's a real regex and should NOT be converted to exact match
            has_regex_chars = re.search(regex_metacharacters, pattern)

            # Only suggest exact match if pattern is purely alphanumeric with underscores/hyphens
            # and contains NO regex metacharacters
            if not has_regex_chars and re.fullmatch(r'[a-zA-Z0-9_\-]+', pattern):
                self.optimizations.append({
                    'type': 'regex_to_exact',
                    'message': f'Label matcher {label}=~"{pattern}" can be an exact match',
                    'severity': 'info',
                    'recommendation': f'Use {label}="{pattern}" instead of =~ for better performance'
                })

            # Check for simple prefix/suffix patterns that might be better structured
            if pattern.endswith('.*'):
                self.suggestions.append({
                    'type': 'regex_optimization',
                    'message': f'Regex pattern "{pattern}" uses wildcard suffix',
                    'severity': 'info',
                    'recommendation': 'Consider if you can use more specific label values'
                })

    def _check_missing_rate_on_counters(self):
        """Check if counter metrics are used without rate/increase"""
        # Find metric names that look like counters
        metric_pattern = r'\b([a-zA-Z_:][a-zA-Z0-9_:]*(?:_total|_count|_sum|_bucket))\b'
        counter_metrics = re.findall(metric_pattern, self.query)

        for metric in counter_metrics:
            # Check if it's wrapped in rate/irate/increase
            escaped_metric = re.escape(metric)
            if not re.search(rf'(?:rate|irate|increase|delta|idelta)\s*\([^)]*{escaped_metric}', self.query):
                # Check if it's in histogram_quantile (buckets are used differently)
                if not re.search(rf'histogram_quantile\s*\([^)]*{escaped_metric}', self.query):
                    # Skip _sum and _count metrics when used in histogram calculations
                    # (they're used for average: _sum / _count)
                    if metric.endswith('_sum') or metric.endswith('_count'):
                        # Check if this is part of a division for average calculation
                        base_metric = metric.rsplit('_', 1)[0]
                        if re.search(rf'{base_metric}_sum.*{base_metric}_count|{base_metric}_count.*{base_metric}_sum', self.query):
                            continue  # Skip - this is a valid average calculation pattern

                    # Skip native histogram metrics (no _bucket suffix needed)
                    # Native histograms use histogram_avg, histogram_stddev, etc.
                    if re.search(rf'histogram_(?:avg|stddev|stdvar|count|sum|fraction)\s*\([^)]*{escaped_metric}', self.query):
                        continue

                    self.issues.append({
                        'type': 'missing_rate',
                        'message': f'Counter metric "{metric}" used without rate() or increase()',
                        'severity': 'warning',
                        'recommendation': f'Use rate({metric}[5m]) to get per-second rate'
                    })

    def _check_rate_on_gauges(self):
        """Check if rate/irate is used on gauge metrics"""
        # Find rate/irate/increase calls
        rate_calls = re.findall(
            r'(rate|irate|increase|delta|idelta)\s*\(\s*([a-zA-Z_:][a-zA-Z0-9_:]*)',
            self.query
        )

        for func, metric in rate_calls:
            # Check if metric name suggests it's a gauge
            is_gauge = any(pattern in metric for pattern in self.GAUGE_PATTERNS)
            is_counter = any(metric.endswith(suffix) for suffix in self.COUNTER_SUFFIXES)

            if is_gauge and not is_counter:
                self.issues.append({
                    'type': 'rate_on_gauge',
                    'message': f'{func}() used on gauge metric "{metric}"',
                    'severity': 'warning',
                    'recommendation': f'Gauges should not use rate(). Use avg_over_time({metric}[5m]) or remove rate()'
                })

    def _check_averaging_quantiles(self):
        """Check for averaging pre-calculated quantiles"""
        # Pattern: avg(...{quantile="..."})
        if re.search(r'avg\s*\([^)]*\{[^}]*quantile\s*=', self.query):
            self.issues.append({
                'type': 'averaging_quantiles',
                'message': 'Averaging pre-calculated quantiles is mathematically invalid',
                'severity': 'error',
                'recommendation': 'Use histogram_quantile() with histogram buckets instead'
            })

    def _check_subquery_performance(self):
        """Check for potentially expensive subqueries"""
        # Pattern: [...:...] subquery syntax
        subquery_pattern = r'\[(\d+)([smhdwy])[^\]]*:\s*(\d+)?([smhdwy])?\]'
        subqueries = re.findall(subquery_pattern, self.query)

        for range_val, range_unit, res_val, res_unit in subqueries:
            # Convert to approximate hours
            range_hours = self._duration_to_hours(int(range_val), range_unit)

            if range_hours > 24 * 7:  # More than 7 days
                self.issues.append({
                    'type': 'expensive_subquery',
                    'message': f'Subquery spans {range_val}{range_unit} which may be very slow',
                    'severity': 'warning',
                    'recommendation': 'Consider using recording rules or reducing the time range'
                })

    def _check_irate_range(self):
        """Check if irate() is used with appropriate time ranges"""
        # irate() should use short ranges (typically < 5m)
        irate_pattern = r'irate\s*\([^)]*\[(\d+)([smhdwy])\]'
        irate_calls = re.findall(irate_pattern, self.query)

        for duration, unit in irate_calls:
            minutes = self._duration_to_minutes(int(duration), unit)

            if minutes > 5:
                self.issues.append({
                    'type': 'irate_long_range',
                    'message': f'irate() used with {duration}{unit} range - irate only looks at last 2 samples',
                    'severity': 'warning',
                    'recommendation': f'Use rate() for ranges > 5m, or reduce irate range to [2m]'
                })

    def _check_rate_range(self):
        """Check if rate() uses appropriate time ranges"""
        # rate() range should be at least 4x scrape interval (typically >= 2m)
        rate_pattern = r'rate\s*\([^)]*\[(\d+)(ms|s|m|h|d|w|y)\]'
        rate_calls = re.findall(rate_pattern, self.query)

        for duration, unit in rate_calls:
            seconds = self._duration_to_seconds(int(duration), unit)

            if seconds < 120:  # Less than 2 minutes
                self.issues.append({
                    'type': 'rate_short_range',
                    'message': f'rate() used with very short range [{duration}{unit}]',
                    'severity': 'warning',
                    'recommendation': 'Rate range should be at least 4x scrape interval, typically [2m] or more'
                })

    def _check_unbounded_queries(self):
        """Check for queries without sufficient constraints"""
        # Look for aggregations without by/without clauses on potentially high-cardinality data
        aggregations = ['sum', 'avg', 'min', 'max', 'count']

        # Check if this appears to be an alerting query (has comparison operator)
        # For alerting, fully aggregated results returning a single value is often intentional
        is_alerting_query = bool(re.search(r'\s*(>|<|>=|<=|==|!=)\s*[\d\.]', self.query))

        for agg in aggregations:
            # Pattern: sum(...) without "by" or "without"
            pattern = rf'{agg}\s*\([^)]+\)(?!\s*(?:by|without)\s*\()'
            if re.search(pattern, self.query):
                if is_alerting_query:
                    # For alerting queries, this is often intentional - use a softer message
                    self.suggestions.append({
                        'type': 'missing_aggregation_clause',
                        'message': f'{agg}() used without by() or without() clause (likely intentional for alerting)',
                        'severity': 'info',
                        'recommendation': f'Full aggregation is common for alerting queries. Add "by (label)" only if you need per-label alerts.'
                    })
                else:
                    # For non-alerting queries, the standard recommendation applies
                    self.suggestions.append({
                        'type': 'missing_aggregation_clause',
                        'message': f'{agg}() used without by() or without() clause',
                        'severity': 'info',
                        'recommendation': f'Consider adding "by (label)" or "without (label)" to {agg}() for clearer results'
                    })

    def _check_aggregation_best_practices(self):
        """Check aggregation operator usage"""
        # Check for count() without by clause (might be intentional, but worth mentioning)
        if re.search(r'count\s*\([^)]+\)(?!\s*by)', self.query):
            self.suggestions.append({
                'type': 'count_without_by',
                'message': 'count() used without by() - this counts all matching series',
                'severity': 'info',
                'recommendation': 'If you want to count by label, use: count(...) by (label)'
            })

    def _check_recording_rule_opportunity(self):
        """Check if query is complex enough to benefit from recording rules"""
        # Heuristics for complex queries:
        # - Multiple nested functions
        # - Multiple aggregations
        # - Subqueries
        # - Long expressions

        complexity_score = 0

        # Count function calls
        func_count = len(re.findall(r'\b[a-z_]+\s*\(', self.query))
        if func_count >= 3:
            complexity_score += 1

        # Check for nested aggregations
        if re.search(r'(sum|avg|min|max)\s*\([^)]*\b(sum|avg|min|max)\s*\(', self.query):
            complexity_score += 1

        # Check for subqueries
        if re.search(r'\[[^\]]+:[^\]]+\]', self.query):
            complexity_score += 1

        # Check query length
        if len(self.query) > 150:
            complexity_score += 1

        if complexity_score >= 2:
            self.suggestions.append({
                'type': 'recording_rule_opportunity',
                'message': 'Query is complex and may benefit from recording rules',
                'severity': 'info',
                'recommendation': 'Consider creating recording rules if this query is used frequently'
            })

    def _check_label_matcher_efficiency(self):
        """Check if label matchers could be more efficient"""
        # Check for multiple OR conditions that might indicate need for regex
        if self.query.count(' or ') >= 2:
            self.suggestions.append({
                'type': 'multiple_or_conditions',
                'message': 'Multiple OR conditions found',
                'severity': 'info',
                'recommendation': 'Consider using regex matcher =~ "value1|value2|value3" if checking same label'
            })

    def _check_histogram_usage(self):
        """Check for proper histogram quantile calculation"""
        # Check for histogram_quantile usage
        if 'histogram_quantile' in self.query:
            # Should include rate() on bucket metrics
            # Note: The rate() can be nested inside aggregations, so we look for both
            # histogram_quantile and rate() appearing anywhere in the query
            has_rate = bool(re.search(r'\brate\s*\(', self.query))
            has_bucket_metric = '_bucket' in self.query

            # Only warn about missing rate if there's a _bucket metric (classic histogram)
            # Native histograms don't have _bucket suffix
            if has_bucket_metric and not has_rate:
                self.issues.append({
                    'type': 'histogram_missing_rate',
                    'message': 'histogram_quantile() should use rate() on bucket metrics',
                    'severity': 'warning',
                    'recommendation': 'Use: histogram_quantile(0.95, sum by (le) (rate(metric_bucket[5m])))'
                })

            # Should aggregate by 'le' label (only for classic histograms with _bucket)
            # Native histograms don't need 'le' label
            if has_bucket_metric:
                # Look for 'le' in any by() clause in the query
                has_le_in_by = bool(re.search(r'\bby\s*\([^)]*\ble\b', self.query))
                if not has_le_in_by:
                    self.issues.append({
                        'type': 'histogram_missing_le',
                        'message': 'histogram_quantile() with classic histograms should aggregate by (le) label',
                        'severity': 'warning',
                        'recommendation': 'Include "le" in the by() clause: sum by (job, le) (...)'
                    })

    def _check_deprecated_functions(self):
        """Check for deprecated functions (Prometheus 3.0+)"""
        # holt_winters is deprecated in Prometheus 3.0, renamed to double_exponential_smoothing
        if re.search(r'\bholt_winters\s*\(', self.query):
            self.issues.append({
                'type': 'deprecated_function',
                'message': 'holt_winters() is deprecated in Prometheus 3.0',
                'severity': 'warning',
                'recommendation': 'Use double_exponential_smoothing() instead (requires --enable-feature=promql-experimental-functions)'
            })

    def _check_predict_linear_range(self):
        """Check if predict_linear() uses appropriate time ranges"""
        # predict_linear() with very short ranges gives unreliable predictions
        predict_pattern = r'predict_linear\s*\([^)]*\[(\d+)(ms|s|m|h|d|w|y)\]'
        predict_calls = re.findall(predict_pattern, self.query)

        for duration, unit in predict_calls:
            minutes = self._duration_to_minutes(int(duration), unit)

            if minutes < 10:
                self.issues.append({
                    'type': 'predict_linear_short_range',
                    'message': f'predict_linear() used with short range [{duration}{unit}]',
                    'severity': 'warning',
                    'recommendation': 'predict_linear() needs sufficient data for reliable predictions. Use at least [10m] or longer.'
                })

    def _check_division_by_zero_risk(self):
        """Check for potential division by zero issues"""
        # Pattern: / rate(..._count...) or / rate(..._total...)
        # This can be zero if no requests occurred
        if re.search(r'/\s*(?:rate|increase)\s*\([^)]*(?:_count|_total)[^)]*\)', self.query):
            self.suggestions.append({
                'type': 'division_by_zero_risk',
                'message': 'Division by rate() or increase() of counter may result in NaN if denominator is 0',
                'severity': 'info',
                'recommendation': 'Consider using "or vector(0)" or "> 0" filter to handle zero denominators'
            })

    def _check_changes_resets_alerting(self):
        """Check for changes() or resets() usage patterns"""
        # changes() and resets() can miss events that happen between scrapes
        if re.search(r'\b(changes|resets)\s*\(', self.query):
            self.suggestions.append({
                'type': 'changes_resets_limitation',
                'message': 'changes() and resets() only detect changes between scraped samples',
                'severity': 'info',
                'recommendation': 'Events occurring between scrapes will be missed. For alerting, consider alternative approaches.'
            })

    def _check_dimensional_metric_names(self):
        """Check for dimensions embedded in metric names (anti-pattern)"""
        # Embedding dimensions in metric names like: http_requests_GET_total, cpu_0_usage
        # This is a bad practice per Google Cloud and Prometheus best practices

        # Look for patterns like: metric_value_total or metric_123_something
        # Common bad patterns: http_requests_GET_200_total, cpu_core0_usage
        bad_patterns = [
            r'\b[a-zA-Z_]+_(GET|POST|PUT|DELETE|PATCH)_[a-zA-Z_]+',  # HTTP methods in name
            r'\b[a-zA-Z_]+_\d+_[a-zA-Z_]+',  # Numbers embedded (like cpu_0_usage)
            r'\b[a-zA-Z_]+_(2\d{2}|3\d{2}|4\d{2}|5\d{2})_[a-zA-Z_]+',  # HTTP status codes in name
        ]

        for pattern in bad_patterns:
            if re.search(pattern, self.query):
                self.suggestions.append({
                    'type': 'dimensional_metric_name',
                    'message': 'Metric name appears to embed dimensions (method, status code, or index)',
                    'severity': 'info',
                    'recommendation': 'Move dimensions to labels instead of embedding in metric names. Example: http_requests_total{method="GET", status="200"}'
                })
                break  # Only warn once

    def _check_absent_with_aggregation(self):
        """
        Check for absent() used with aggregation functions.

        Per https://stackoverflow.com/questions/53191746/prometheus-absent-function
        and https://www.robustperception.io/functions-to-avoid/

        absent() returns 1 if no time series match the selector, 0 otherwise.
        When combined with aggregation, it doesn't work as expected because:
        - absent(sum(metric)) will return empty if ANY metric matches
        - It cannot detect per-label absence

        For label-aware absence detection, use:
        group(present_over_time(metric[range])) by (labels)
        unless
        group(metric) by (labels)
        """
        # Pattern: absent(aggregation_function(...))
        if re.search(r'absent\s*\(\s*(sum|avg|min|max|count|group|stddev|stdvar)\s*\(', self.query):
            self.issues.append({
                'type': 'absent_with_aggregation',
                'message': 'absent() with aggregation may not work as expected',
                'severity': 'warning',
                'recommendation': 'absent() checks if a selector returns no data. Aggregations return data if ANY series matches. For per-label absence, use: group(present_over_time(metric[range])) unless group(metric)'
            })

        # Pattern: absent(...) by (label) - absent doesn't support by()
        if re.search(r'absent\s*\([^)]+\)\s*by\s*\(', self.query):
            self.issues.append({
                'type': 'absent_with_by',
                'message': 'absent() does not support by() clause for per-label grouping',
                'severity': 'error',
                'recommendation': 'absent() returns a single value. For per-label absence detection, use: group(present_over_time(metric[range])) by (labels) unless group(metric) by (labels)'
            })

    def _check_vector_matching(self):
        """
        Check for common vector matching mistakes with on/ignoring/group_left/group_right.

        Per https://grafana.com/blog/2024/12/13/promql-vector-matching-what-it-is-and-how-it-affects-your-prometheus-queries/
        and https://iximiuz.com/en/posts/prometheus-vector-matching/

        Common issues:
        1. Missing group_left/group_right for many-to-one joins
        2. Using group_right when group_left should be used
        3. Missing on() or ignoring() when label sets don't match
        """
        query_lower = self.query.lower()

        # Check for binary operations that might need vector matching
        # Pattern: metric * metric or metric / metric without on() or ignoring()
        binary_ops = ['*', '/', '+', '-', '%', '^']
        has_binary_op = any(op in self.query for op in binary_ops)
        has_vector_matching = 'on(' in query_lower or 'ignoring(' in query_lower

        # Check for _info metric joins (common pattern)
        # Info metrics typically need group_left
        if re.search(r'\*\s*on\s*\([^)]+\)\s*[a-zA-Z_]+_info\b', self.query):
            if 'group_left' not in query_lower and 'group_right' not in query_lower:
                self.issues.append({
                    'type': 'info_metric_missing_group',
                    'message': 'Joining with _info metric without group_left()',
                    'severity': 'warning',
                    'recommendation': 'Info metric joins typically need group_left() to bring labels from the info metric. Use: metric * on(job, instance) group_left(label1, label2) info_metric'
                })

        # Check for group_left/group_right without on() or ignoring()
        if re.search(r'\b(group_left|group_right)\s*\(', query_lower):
            if 'on(' not in query_lower and 'ignoring(' not in query_lower:
                self.issues.append({
                    'type': 'group_without_matching',
                    'message': 'group_left()/group_right() used without on() or ignoring()',
                    'severity': 'error',
                    'recommendation': 'group_left()/group_right() requires on() or ignoring() to specify matching labels'
                })

        # Check for on() with empty parentheses - this is valid but might be unintentional
        if re.search(r'\bon\s*\(\s*\)', query_lower):
            self.suggestions.append({
                'type': 'on_empty_labels',
                'message': 'on() with empty labels matches all series',
                'severity': 'info',
                'recommendation': 'on() with empty parentheses ignores all labels for matching. Ensure this is intentional.'
            })

        # Check for potential many-to-many matching (error-prone)
        # If there's a binary op with on() but no group_left/group_right, it might fail at runtime
        if has_vector_matching and 'group_left' not in query_lower and 'group_right' not in query_lower:
            # This is just informational since one-to-one might be intended
            self.suggestions.append({
                'type': 'vector_matching_cardinality',
                'message': 'Binary operation with on()/ignoring() assumes one-to-one matching',
                'severity': 'info',
                'recommendation': 'If you have many-to-one or one-to-many cardinality, add group_left() or group_right(). Error "multiple matches for labels" indicates cardinality mismatch.'
            })

    def _check_native_histogram_usage(self):
        """
        Check for proper native histogram function usage (Prometheus 2.40+/3.0).

        Per https://prometheus.io/docs/specs/native_histograms/
        and https://prometheus.io/blog/2024/11/14/prometheus-3-0/

        Native histograms:
        - Don't need _bucket suffix
        - Don't need 'le' label in aggregation
        - Still need rate() for proper calculation
        - Use histogram_avg, histogram_stddev, etc.
        """
        # Check for native histogram functions
        native_hist_pattern = r'\b(histogram_avg|histogram_stddev|histogram_stdvar)\s*\('
        native_hist_matches = re.findall(native_hist_pattern, self.query)

        for func in native_hist_matches:
            # Check if rate() is used (required for native histograms too)
            func_call_pattern = rf'{func}\s*\([^)]*'
            if not re.search(rf'{func}\s*\(\s*rate\s*\(', self.query):
                self.issues.append({
                    'type': 'native_histogram_missing_rate',
                    'message': f'{func}() should use rate() on the histogram metric',
                    'severity': 'warning',
                    'recommendation': f'Use: {func}(rate(histogram_metric[5m]))'
                })

        # Check for histogram_quantile with native histogram patterns
        # Native histograms don't need 'le' in by() clause
        if 'histogram_quantile' in self.query:
            # Check if this looks like a native histogram query (no _bucket suffix)
            # Native histogram: histogram_quantile(0.95, sum by (job) (rate(metric[5m])))
            # Classic histogram: histogram_quantile(0.95, sum by (job, le) (rate(metric_bucket[5m])))

            # Look for _bucket anywhere in the query (not just immediately after histogram_quantile)
            # since the bucket metric could be inside nested functions
            has_bucket_suffix = '_bucket' in self.query
            has_le_in_by = bool(re.search(r'\bby\s*\([^)]*\ble\b', self.query))

            # Only warn about unnecessary 'le' for native histograms (no _bucket suffix)
            # If there's a _bucket metric, this is a classic histogram and 'le' IS required
            if not has_bucket_suffix and has_le_in_by:
                self.suggestions.append({
                    'type': 'native_histogram_unnecessary_le',
                    'message': 'Native histograms do not need "le" label in aggregation',
                    'severity': 'info',
                    'recommendation': 'For native histograms, simplify to: histogram_quantile(0.95, sum by (job) (rate(metric[5m])))'
                })

            # If has _bucket but no le - classic histogram missing le (already covered by _check_histogram_usage)
            # If no _bucket and no le - could be native histogram (OK) or classic without le (error)

        # Provide helpful info about histogram_count and histogram_sum
        # These work with both native and classic histograms but differently
        if re.search(r'\bhistogram_count\s*\(', self.query) or re.search(r'\bhistogram_sum\s*\(', self.query):
            # Check if it's wrapping rate()
            if not re.search(r'histogram_(?:count|sum)\s*\(\s*rate\s*\(', self.query):
                self.suggestions.append({
                    'type': 'histogram_helper_without_rate',
                    'message': 'histogram_count()/histogram_sum() typically need rate() for meaningful results',
                    'severity': 'info',
                    'recommendation': 'Use: histogram_count(rate(histogram_metric[5m])) to get observations per second'
                })

    def _check_mixed_metric_types(self):
        """
        Check if query combines fundamentally different metric types in a single expression.

        Mixing counters, gauges, histograms, and summaries in arithmetic operations
        often produces meaningless results. Each metric type has different semantics:
        - Counters: Cumulative values that only increase
        - Gauges: Point-in-time values that can go up or down
        - Histograms: Bucketed observations for distribution analysis
        - Summaries: Pre-calculated quantiles

        Combining them (e.g., latency / memory + request_count) rarely makes sense.

        EXCEPTION: histogram_quantile with _bucket metrics is NOT mixed types - this is
        the correct pattern for classic histograms. The _bucket suffix doesn't indicate
        a counter being used incorrectly; it's part of the histogram data model.
        """
        # Detect metric types in the query
        detected_types = set()
        type_examples = {}

        # Check if this is a histogram_quantile query with classic histograms
        # In this case, _bucket metrics are expected and should not be flagged as "counter"
        is_classic_histogram_query = 'histogram_quantile' in self.query and '_bucket' in self.query

        # Find all metric names in the query (outside of {...} blocks)
        query_clean = self._strip_label_selectors_and_strings(self.query)
        metric_pattern = r'\b([a-zA-Z_:][a-zA-Z0-9_:]*)\b'
        potential_metrics = re.findall(metric_pattern, query_clean)

        # Filter out reserved words
        reserved_words = {
            'sum', 'avg', 'min', 'max', 'count', 'stddev', 'stdvar', 'group',
            'topk', 'bottomk', 'quantile', 'count_values', 'limitk', 'limit_ratio',
            'rate', 'irate', 'increase', 'delta', 'idelta', 'deriv', 'predict_linear',
            'histogram_quantile', 'histogram_count', 'histogram_sum', 'histogram_fraction',
            'histogram_avg', 'histogram_stddev', 'histogram_stdvar',
            'abs', 'ceil', 'floor', 'round', 'sqrt', 'exp', 'ln', 'log2', 'log10',
            'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
            'deg', 'rad', 'sgn', 'clamp', 'clamp_max', 'clamp_min', 'pi',
            'timestamp', 'time', 'minute', 'hour', 'day_of_month', 'day_of_week',
            'days_in_month', 'month', 'year',
            'label_replace', 'label_join', 'vector', 'scalar',
            'changes', 'resets', 'absent', 'absent_over_time', 'present_over_time',
            'avg_over_time', 'min_over_time', 'max_over_time', 'sum_over_time',
            'count_over_time', 'quantile_over_time', 'stddev_over_time', 'stdvar_over_time',
            'last_over_time', 'mad_over_time', 'sort', 'sort_desc', 'sort_by_label',
            'sort_by_label_desc', 'holt_winters', 'double_exponential_smoothing', 'info',
            'by', 'without', 'and', 'or', 'unless', 'on', 'ignoring',
            'group_left', 'group_right', 'bool', 'offset', 'start', 'end',
            'inf', 'nan'
        }

        metrics = [m for m in potential_metrics if m.lower() not in reserved_words]

        for metric in metrics:
            # Classify metric type
            # For _bucket metrics in histogram_quantile queries, treat them as histogram components
            # not as standalone counters
            if metric.endswith('_bucket') and is_classic_histogram_query:
                # This is part of a classic histogram query - don't flag as counter
                continue
            elif any(metric.endswith(suffix) for suffix in ['_total', '_count', '_sum', '_bucket']):
                detected_types.add('counter')
                type_examples.setdefault('counter', []).append(metric)
            elif any(pattern in metric for pattern in self.GAUGE_PATTERNS):
                detected_types.add('gauge')
                type_examples.setdefault('gauge', []).append(metric)
            elif 'quantile' in self.query and metric in self.query:
                # Check if this metric is used with a quantile label selector
                if re.search(rf'{re.escape(metric)}\s*\{{[^}}]*quantile\s*=', self.query):
                    detected_types.add('summary')
                    type_examples.setdefault('summary', []).append(metric)

        # Check for histogram usage via histogram_quantile
        # Only add 'histogram' as a type if it's NOT a classic histogram query
        # (where _bucket metrics are expected and handled above)
        if 'histogram_quantile' in self.query and not is_classic_histogram_query:
            detected_types.add('histogram')
            type_examples.setdefault('histogram', []).append('(histogram_quantile usage)')

        # Warn if multiple different metric types are combined with arithmetic
        if len(detected_types) >= 2:
            # Check if there are arithmetic operators combining these
            arithmetic_ops = ['+', '-', '*', '/']
            has_arithmetic = any(op in self.query for op in arithmetic_ops)

            if has_arithmetic:
                type_list = ', '.join(sorted(detected_types))
                examples = []
                for t, metrics_list in type_examples.items():
                    examples.append(f"{t}: {metrics_list[0]}")

                self.issues.append({
                    'type': 'mixed_metric_types',
                    'message': f'Query combines different metric types ({type_list}) in arithmetic operations',
                    'severity': 'warning',
                    'recommendation': f'Mixing metric types often produces meaningless results. Examples found: {"; ".join(examples)}. Consider separating into distinct queries or ensure the combination makes semantic sense.'
                })

    @staticmethod
    def _duration_to_seconds(value: int, unit: str) -> int:
        """Convert duration to seconds"""
        units = {
            'ms': 0.001,
            's': 1,
            'm': 60,
            'h': 3600,
            'd': 86400,
            'w': 604800,
            'y': 31536000
        }
        return int(value * units.get(unit, 1))

    @staticmethod
    def _duration_to_minutes(value: int, unit: str) -> float:
        """Convert duration to minutes"""
        return PromQLBestPracticesChecker._duration_to_seconds(value, unit) / 60

    @staticmethod
    def _duration_to_hours(value: int, unit: str) -> float:
        """Convert duration to hours"""
        return PromQLBestPracticesChecker._duration_to_seconds(value, unit) / 3600

    def _build_result(self) -> Dict:
        """Build the check result dictionary"""
        all_findings = self.issues + self.suggestions + self.optimizations

        has_errors = any(item['severity'] == 'error' for item in all_findings)
        has_warnings = any(item['severity'] == 'warning' for item in all_findings)

        if has_errors:
            status = 'ERROR'
        elif has_warnings:
            status = 'WARNING'
        elif self.optimizations or self.suggestions:
            status = 'CAN_BE_IMPROVED'
        else:
            status = 'OPTIMIZED'

        return {
            'status': status,
            'query': self.query,
            'issues': self.issues,
            'suggestions': self.suggestions,
            'optimizations': self.optimizations,
            'summary': {
                'errors': len([i for i in self.issues if i['severity'] == 'error']),
                'warnings': len([i for i in self.issues if i['severity'] == 'warning']),
                'suggestions': len(self.suggestions),
                'optimizations': len(self.optimizations)
            }
        }


def main():
    """Main entry point for the best practices checker"""
    if len(sys.argv) < 2:
        print(json.dumps({
            'status': 'ERROR',
            'message': 'Usage: check_best_practices.py "<promql_query>"'
        }, indent=2))
        sys.exit(1)

    query = sys.argv[1]
    checker = PromQLBestPracticesChecker(query)
    result = checker.check()

    print(json.dumps(result, indent=2))

    # Exit with error code if there are errors
    sys.exit(0 if result['summary']['errors'] == 0 else 1)


if __name__ == '__main__':
    main()