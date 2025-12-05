#!/usr/bin/env python3
"""
PromQL Syntax Validator

Validates the syntax of Prometheus Query Language (PromQL) expressions.
Checks for correct metric names, label matchers, operators, functions, and time durations.
"""

import re
import sys
import json
from typing import Dict, List, Tuple, Optional


class PromQLSyntaxValidator:
    """Validates PromQL query syntax"""

    # Regex patterns for PromQL syntax elements
    METRIC_NAME_PATTERN = r'[a-zA-Z_:][a-zA-Z0-9_:]*'
    DURATION_PATTERN = r'\d+(?:ms|s|m|h|d|w|y)'
    LABEL_MATCHER_PATTERN = r'[a-zA-Z_][a-zA-Z0-9_]*\s*(?:=|!=|=~|!~)\s*"(?:[^"\\]|\\.)*"'

    # Valid PromQL functions
    FUNCTIONS = {
        # Aggregation operators
        'sum', 'min', 'max', 'avg', 'group', 'stddev', 'stdvar', 'count', 'count_values',
        'bottomk', 'topk', 'quantile',
        # Limiting functions (Prometheus 2.43+, experimental)
        'limitk', 'limit_ratio',
        # Rate/increase functions
        'rate', 'irate', 'increase', 'delta', 'idelta', 'deriv',
        # Time functions
        'timestamp', 'time', 'minute', 'hour', 'day_of_month', 'day_of_week',
        'days_in_month', 'month', 'year',
        # Math functions
        'abs', 'ceil', 'floor', 'round', 'sqrt', 'exp', 'ln', 'log2', 'log10',
        'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
        'asinh', 'acosh', 'atanh', 'deg', 'rad', 'sgn', 'clamp', 'clamp_max', 'clamp_min',
        # Histogram/summary functions (classic)
        'histogram_quantile', 'histogram_count', 'histogram_sum', 'histogram_fraction',
        # Native histogram functions (Prometheus 2.40+/3.0)
        'histogram_avg', 'histogram_stddev', 'histogram_stdvar',
        # Label manipulation
        'label_replace', 'label_join',
        # Over time functions
        'changes', 'resets', 'avg_over_time', 'min_over_time', 'max_over_time',
        'sum_over_time', 'count_over_time', 'quantile_over_time', 'stddev_over_time',
        'stdvar_over_time', 'last_over_time', 'present_over_time', 'mad_over_time',
        # Prediction functions
        'predict_linear',
        'holt_winters',  # Deprecated in Prometheus 3.0, use double_exponential_smoothing
        'double_exponential_smoothing',  # Prometheus 3.0+ (replaces holt_winters, experimental)
        # Sorting functions
        'sort', 'sort_desc', 'sort_by_label', 'sort_by_label_desc',
        # Other functions
        'absent', 'absent_over_time', 'scalar', 'vector',
        # Metric joining (experimental)
        'info',
        # Trigonometric functions
        'pi',
    }

    # Aggregation operators that support by/without clauses
    AGGREGATION_OPERATORS = {
        'sum', 'min', 'max', 'avg', 'group', 'stddev', 'stdvar', 'count',
        'count_values', 'bottomk', 'topk', 'quantile',
        # Prometheus 2.43+ (experimental, requires --enable-feature=promql-experimental-functions)
        'limitk', 'limit_ratio'
    }

    # Binary operators
    BINARY_OPERATORS = {
        '+', '-', '*', '/', '%', '^',  # Arithmetic
        '==', '!=', '>', '<', '>=', '<=',  # Comparison
        'and', 'or', 'unless',  # Logical
    }

    # Keywords that look like functions (followed by parentheses) but are NOT functions
    # These are aggregation modifiers, vector matching keywords, etc.
    NON_FUNCTION_KEYWORDS = {
        'by',           # Aggregation modifier: sum by (label)
        'without',      # Aggregation modifier: sum without (label)
        'on',           # Vector matching: metric_a + on (label) metric_b
        'ignoring',     # Vector matching: metric_a + ignoring (label) metric_b
        'group_left',   # Vector matching: one-to-many joins
        'group_right',  # Vector matching: many-to-one joins
        'bool',         # Comparison modifier: metric > bool 10
    }

    def __init__(self, query: str):
        self.query = query.strip()
        self.errors: List[Dict] = []
        self.warnings: List[Dict] = []

    def validate(self) -> Dict:
        """
        Run all validation checks

        Returns:
            Dict containing validation results
        """
        if not self.query:
            self.errors.append({
                'type': 'empty_query',
                'message': 'Query is empty',
                'severity': 'error'
            })
            return self._build_result()

        # Check for balanced brackets and quotes
        self._check_balanced_delimiters()

        # Check for valid metric names and selectors
        self._check_metric_selectors()

        # Check for valid time ranges
        self._check_time_ranges()

        # Check function syntax
        self._check_function_syntax()

        # Check operators
        self._check_operators()

        # Check for common typos
        self._check_common_typos()

        return self._build_result()

    def _check_balanced_delimiters(self):
        """Check for balanced brackets, braces, and quotes"""
        brackets = []
        braces = []
        parens = []
        in_string = False
        escape_next = False

        for i, char in enumerate(self.query):
            if escape_next:
                escape_next = False
                continue

            if char == '\\':
                escape_next = True
                continue

            if char == '"':
                in_string = not in_string
                continue

            if in_string:
                continue

            if char == '[':
                brackets.append(i)
            elif char == ']':
                if not brackets:
                    self.errors.append({
                        'type': 'unmatched_bracket',
                        'message': f'Unmatched closing bracket at position {i}',
                        'position': i,
                        'severity': 'error'
                    })
                else:
                    brackets.pop()
            elif char == '{':
                braces.append(i)
            elif char == '}':
                if not braces:
                    self.errors.append({
                        'type': 'unmatched_brace',
                        'message': f'Unmatched closing brace at position {i}',
                        'position': i,
                        'severity': 'error'
                    })
                else:
                    braces.pop()
            elif char == '(':
                parens.append(i)
            elif char == ')':
                if not parens:
                    self.errors.append({
                        'type': 'unmatched_paren',
                        'message': f'Unmatched closing parenthesis at position {i}',
                        'position': i,
                        'severity': 'error'
                    })
                else:
                    parens.pop()

        if in_string:
            self.errors.append({
                'type': 'unclosed_string',
                'message': 'Unclosed string literal',
                'severity': 'error'
            })

        if brackets:
            self.errors.append({
                'type': 'unclosed_bracket',
                'message': f'Unclosed bracket at position {brackets[-1]}',
                'position': brackets[-1],
                'severity': 'error'
            })

        if braces:
            self.errors.append({
                'type': 'unclosed_brace',
                'message': f'Unclosed brace at position {braces[-1]}',
                'position': braces[-1],
                'severity': 'error'
            })

        if parens:
            self.errors.append({
                'type': 'unclosed_paren',
                'message': f'Unclosed parenthesis at position {parens[-1]}',
                'position': parens[-1],
                'severity': 'error'
            })

    def _check_metric_selectors(self):
        """Check for valid metric names and label selectors"""
        # Pattern for metric selector (metric name with optional label matchers)
        # Matches: metric_name{label="value"} or {label="value"} or {"metric.name"}

        # Find all potential metric selectors
        # Remove strings first to avoid false matches
        query_no_strings = re.sub(r'"(?:[^"\\]|\\.)*"', '""', self.query)

        # Check for empty label matchers
        if re.search(r'\{\s*\}', query_no_strings):
            self.warnings.append({
                'type': 'empty_label_matcher',
                'message': 'Empty label matcher {} found - this may match many time series',
                'severity': 'warning'
            })

        # Validate UTF-8 metric name syntax (Prometheus 3.0+)
        # Valid: {"my.metric"} or {"my.metric", label="value"}
        # Per https://prometheus.io/docs/guides/utf8/
        self._check_utf8_metric_syntax()

    def _check_utf8_metric_syntax(self):
        """
        Validate UTF-8 metric name quoting syntax (Prometheus 3.0+)

        Per Prometheus docs, UTF-8 metric names must be:
        - Enclosed in double quotes
        - Placed within curly braces as the first element
        - Format: {"my.metric"} or {"my.metric", label="value"}
        """
        # Pattern for quoted metric name selector (UTF-8 syntax)
        # Matches: {"metric.name"} or {"metric.name", label="value", ...}
        utf8_selector_pattern = r'\{\s*"([^"]+)"'

        utf8_matches = re.finditer(utf8_selector_pattern, self.query)

        for match in utf8_matches:
            metric_name = match.group(1)

            # Check if this looks like it should be a UTF-8 metric name
            # (contains characters not valid in classic metric names)
            classic_valid = re.fullmatch(self.METRIC_NAME_PATTERN, metric_name)

            if classic_valid:
                # Metric name is valid in classic format, quoting is optional but valid
                self.warnings.append({
                    'type': 'utf8_metric_unnecessary_quoting',
                    'message': f'Metric name "{metric_name}" uses UTF-8 quoting but is valid in classic format',
                    'severity': 'info'
                })
            else:
                # This is a proper UTF-8 metric name (has special chars like dots)
                # Validate the UTF-8 name format
                if not metric_name.strip():
                    self.errors.append({
                        'type': 'invalid_utf8_metric',
                        'message': 'Empty quoted metric name in UTF-8 selector',
                        'severity': 'error'
                    })
                # UTF-8 metric names can contain any valid UTF-8 character except null
                elif '\x00' in metric_name:
                    self.errors.append({
                        'type': 'invalid_utf8_metric',
                        'message': f'Metric name "{metric_name}" contains null character',
                        'severity': 'error'
                    })

        # Check for common UTF-8 syntax mistakes
        # Wrong: {my.metric="value"} - should be {"my.metric"}
        # This pattern looks for unquoted metric-like names with dots used as label names
        wrong_utf8_pattern = r'\{\s*([a-zA-Z_][a-zA-Z0-9_.]*\.[a-zA-Z0-9_.]+)\s*='
        wrong_matches = re.finditer(wrong_utf8_pattern, self.query)

        for match in wrong_matches:
            suspicious_name = match.group(1)
            # Only flag if it contains dots (likely meant to be a UTF-8 metric name)
            if '.' in suspicious_name:
                self.warnings.append({
                    'type': 'possible_utf8_syntax_error',
                    'message': f'Label name "{suspicious_name}" contains dots - did you mean to use UTF-8 metric syntax?',
                    'severity': 'warning',
                    'hint': f'For UTF-8 metric names use: {{"{suspicious_name}"}}'
                })

    def _check_time_ranges(self):
        """Check for valid time range syntax"""
        # Find all range vectors [duration]
        range_pattern = r'\[([^\]]+)\]'
        ranges = re.findall(range_pattern, self.query)

        for range_str in ranges:
            range_str = range_str.strip()

            # Check if it's a subquery (has colon)
            if ':' in range_str:
                # Subquery format: [range:resolution] or [range:]
                parts = range_str.split(':')
                if len(parts) > 2:
                    self.errors.append({
                        'type': 'invalid_subquery',
                        'message': f'Invalid subquery syntax: [{range_str}]',
                        'severity': 'error'
                    })
                    continue

                range_part = parts[0].strip()
                resolution_part = parts[1].strip() if len(parts) > 1 else ''

                if range_part and not re.fullmatch(self.DURATION_PATTERN, range_part):
                    self.errors.append({
                        'type': 'invalid_duration',
                        'message': f'Invalid duration in subquery range: {range_part}',
                        'severity': 'error'
                    })

                if resolution_part and not re.fullmatch(self.DURATION_PATTERN, resolution_part):
                    self.errors.append({
                        'type': 'invalid_duration',
                        'message': f'Invalid duration in subquery resolution: {resolution_part}',
                        'severity': 'error'
                    })
            else:
                # Regular range vector
                if not re.fullmatch(self.DURATION_PATTERN, range_str):
                    self.errors.append({
                        'type': 'invalid_duration',
                        'message': f'Invalid duration syntax: {range_str}. Expected format like 5m, 1h, 7d',
                        'severity': 'error'
                    })

    def _check_function_syntax(self):
        """Check for valid function usage"""
        # Find all function calls
        func_pattern = r'([a-z_][a-z0-9_]*)\s*\('
        functions = re.findall(func_pattern, self.query, re.IGNORECASE)

        for func in functions:
            func_lower = func.lower()

            # Skip keywords that look like functions but aren't
            # (e.g., "by", "without", "on", "ignoring", "group_left", "group_right")
            if func_lower in self.NON_FUNCTION_KEYWORDS:
                continue

            if func_lower not in self.FUNCTIONS:
                # Check if it might be a typo
                close_matches = self._find_close_matches(func_lower, self.FUNCTIONS)
                if close_matches:
                    self.errors.append({
                        'type': 'unknown_function',
                        'message': f'Unknown function: {func}. Did you mean: {", ".join(close_matches)}?',
                        'severity': 'error'
                    })
                else:
                    self.errors.append({
                        'type': 'unknown_function',
                        'message': f'Unknown function: {func}',
                        'severity': 'error'
                    })

    def _check_operators(self):
        """Check for valid operator usage"""
        # Check for double operators (typos like ++ or --)
        if re.search(r'[+\-*/]{2,}', self.query):
            self.warnings.append({
                'type': 'double_operator',
                'message': 'Found consecutive operators - this might be a typo',
                'severity': 'warning'
            })

    def _check_common_typos(self):
        """Check for common typos and mistakes"""
        # Check for 'rate()' without range vector
        if re.search(r'\b(rate|irate|increase|delta|idelta)\s*\(\s*[a-zA-Z_:][a-zA-Z0-9_:]*\s*(?:\{[^}]*\})?\s*\)', self.query):
            self.errors.append({
                'type': 'missing_range_vector',
                'message': 'rate(), irate(), increase(), delta(), and idelta() require a range vector [duration]',
                'severity': 'error'
            })

        # Check for 'offset' keyword - valid positions:
        # 1. metric_name offset 1h (instant vector)
        # 2. metric_name[5m] offset 1h (range vector)
        # 3. rate(metric_name[5m] offset 1h) (inside function)
        # Invalid: metric_name offset 1h [5m] (offset between metric and range)
        if ' offset ' in self.query.lower():
            # Check for invalid pattern: offset followed by range vector
            if re.search(r'\boffset\s+\d+[smhdwy]\s*\[', self.query, re.IGNORECASE):
                self.errors.append({
                    'type': 'misplaced_offset',
                    'message': 'offset modifier should come after the range vector [duration], not before it',
                    'severity': 'error'
                })

    def _find_close_matches(self, word: str, candidates: set, max_distance: int = 2) -> List[str]:
        """Find close matches using simple edit distance"""
        matches = []
        for candidate in candidates:
            if abs(len(word) - len(candidate)) > max_distance:
                continue
            if self._levenshtein_distance(word, candidate) <= max_distance:
                matches.append(candidate)
        return matches[:3]  # Return top 3 matches

    @staticmethod
    def _levenshtein_distance(s1: str, s2: str) -> int:
        """Calculate Levenshtein distance between two strings"""
        if len(s1) < len(s2):
            return PromQLSyntaxValidator._levenshtein_distance(s2, s1)
        if len(s2) == 0:
            return len(s1)

        previous_row = range(len(s2) + 1)
        for i, c1 in enumerate(s1):
            current_row = [i + 1]
            for j, c2 in enumerate(s2):
                insertions = previous_row[j + 1] + 1
                deletions = current_row[j] + 1
                substitutions = previous_row[j] + (c1 != c2)
                current_row.append(min(insertions, deletions, substitutions))
            previous_row = current_row

        return previous_row[-1]

    def _build_result(self) -> Dict:
        """Build the validation result dictionary"""
        has_errors = len(self.errors) > 0
        has_warnings = len(self.warnings) > 0

        if has_errors:
            status = 'ERROR'
        elif has_warnings:
            status = 'WARNING'
        else:
            status = 'VALID'

        return {
            'status': status,
            'query': self.query,
            'errors': self.errors,
            'warnings': self.warnings,
            'valid': not has_errors
        }


def main():
    """Main entry point for the syntax validator"""
    if len(sys.argv) < 2:
        print(json.dumps({
            'status': 'ERROR',
            'message': 'Usage: validate_syntax.py "<promql_query>"'
        }, indent=2))
        sys.exit(1)

    query = sys.argv[1]
    validator = PromQLSyntaxValidator(query)
    result = validator.validate()

    print(json.dumps(result, indent=2))

    # Exit with error code if validation failed
    sys.exit(0 if result['valid'] else 1)


if __name__ == '__main__':
    main()
