"""
Helper functions for generating proper Groovy/Jenkins syntax
"""

import re
from typing import List, Dict, Optional


class GroovySyntax:
    """Helper functions for generating Groovy syntax"""

    @staticmethod
    def format_string(value: str) -> str:
        """Format a string with proper Groovy quoting"""
        if "'" in value and '"' not in value:
            return f'"{value}"'
        elif '"' in value and "'" not in value:
            return f"'{value}'"
        elif '"' in value and "'" in value:
            # Use triple quotes
            return f"'''{value}'''"
        else:
            return f"'{value}'"

    @staticmethod
    def format_list(items: List[str]) -> str:
        """Format a list in Groovy syntax"""
        formatted_items = [GroovySyntax.format_string(item) for item in items]
        return f"[{', '.join(formatted_items)}]"

    @staticmethod
    def format_map(data: Dict[str, str]) -> str:
        """Format a map/dict in Groovy syntax"""
        formatted_items = [f"{k}: {GroovySyntax.format_string(v)}" for k, v in data.items()]
        return f"[{', '.join(formatted_items)}]"

    @staticmethod
    def format_multiline_string(text: str, indent: int = 0) -> str:
        """Format multiline string with proper indentation"""
        lines = text.strip().split('\n')
        indent_str = '    ' * indent
        formatted_lines = [f"{indent_str}{line}" for line in lines]
        return '\n'.join(formatted_lines)

    @staticmethod
    def escape_groovy_string(text: str) -> str:
        """Escape special characters in Groovy strings"""
        # Escape backslashes first
        text = text.replace('\\', '\\\\')
        # Escape quotes
        text = text.replace("'", "\\'")
        # Escape dollar signs (for GString interpolation)
        text = text.replace('$', '\\$')
        return text

    @staticmethod
    def format_closure(content: str, indent: int = 0) -> str:
        """Format a Groovy closure with proper bracing"""
        indent_str = '    ' * indent
        return f"{indent_str}{{\n{content}\n{indent_str}}}"


class DeclarativeSyntax:
    """Helper functions specific to Declarative Pipeline syntax"""

    @staticmethod
    def agent_block(agent_type: str, **kwargs) -> str:
        """Generate agent block"""
        if agent_type == 'any':
            return "    agent any"
        elif agent_type == 'none':
            return "    agent none"
        elif agent_type == 'label':
            label = kwargs.get('label', 'linux')
            return f"    agent {{ label '{label}' }}"
        elif agent_type == 'docker':
            image = kwargs.get('image', 'ubuntu:latest')
            args = kwargs.get('args', '')
            reuseNode = kwargs.get('reuseNode', False)

            agent_config = [f"image '{image}'"]
            if args:
                agent_config.append(f"args '{args}'")
            if reuseNode:
                agent_config.append("reuseNode true")

            config_str = '\n            '.join(agent_config)
            return f"""    agent {{
        docker {{
            {config_str}
        }}
    }}"""
        elif agent_type == 'dockerfile':
            filename = kwargs.get('filename', 'Dockerfile')
            dir_path = kwargs.get('dir', '.')
            additionalBuildArgs = kwargs.get('additionalBuildArgs', '')

            if filename == 'Dockerfile' and dir_path == '.' and not additionalBuildArgs:
                return "    agent { dockerfile true }"
            else:
                agent_config = []
                if filename != 'Dockerfile':
                    agent_config.append(f"filename '{filename}'")
                if dir_path != '.':
                    agent_config.append(f"dir '{dir_path}'")
                if additionalBuildArgs:
                    agent_config.append(f"additionalBuildArgs '{additionalBuildArgs}'")

                config_str = '\n            '.join(agent_config)
                return f"""    agent {{
        dockerfile {{
            {config_str}
        }}
    }}"""
        elif agent_type == 'kubernetes':
            yaml_content = kwargs.get('yaml', '')
            inheritFrom = kwargs.get('inheritFrom', '')

            if inheritFrom:
                return f"""    agent {{
        kubernetes {{
            inheritFrom '{inheritFrom}'
            yaml '''
{yaml_content}
'''
        }}
    }}"""
            else:
                return f"""    agent {{
        kubernetes {{
            yaml '''
{yaml_content}
'''
        }}
    }}"""
        else:
            return "    agent any"

    @staticmethod
    def environment_block(env_vars: Dict[str, str], credentials: Dict[str, str] = None) -> str:
        """Generate environment block"""
        if not env_vars and not credentials:
            return ""

        lines = ["    environment {"]

        # Regular environment variables
        for key, value in env_vars.items():
            lines.append(f"        {key} = '{value}'")

        # Credential bindings
        if credentials:
            for key, cred_id in credentials.items():
                lines.append(f"        {key} = credentials('{cred_id}')")

        lines.append("    }")
        return '\n'.join(lines)

    @staticmethod
    def parameters_block(parameters: List[Dict]) -> str:
        """Generate parameters block"""
        if not parameters:
            return ""

        lines = ["    parameters {"]

        for param in parameters:
            param_type = param.get('type', 'string')
            name = param.get('name', 'PARAM')
            default_value = param.get('defaultValue', '')
            description = param.get('description', '')

            if param_type == 'string':
                lines.append(f"        string(name: '{name}', defaultValue: '{default_value}', description: '{description}')")
            elif param_type == 'text':
                lines.append(f"        text(name: '{name}', defaultValue: '{default_value}', description: '{description}')")
            elif param_type == 'boolean':
                default_bool = 'true' if default_value else 'false'
                lines.append(f"        booleanParam(name: '{name}', defaultValue: {default_bool}, description: '{description}')")
            elif param_type == 'choice':
                choices = param.get('choices', [])
                choices_str = ', '.join([f"'{c}'" for c in choices])
                lines.append(f"        choice(name: '{name}', choices: [{choices_str}], description: '{description}')")
            elif param_type == 'password':
                lines.append(f"        password(name: '{name}', defaultValue: '{default_value}', description: '{description}')")

        lines.append("    }")
        return '\n'.join(lines)

    @staticmethod
    def options_block(options: Dict[str, any]) -> str:
        """Generate options block"""
        if not options:
            return ""

        lines = ["    options {"]

        if options.get('buildDiscarder'):
            num_to_keep = options['buildDiscarder'].get('numToKeepStr', '10')
            lines.append(f"        buildDiscarder(logRotator(numToKeepStr: '{num_to_keep}'))")

        if options.get('disableConcurrentBuilds'):
            lines.append("        disableConcurrentBuilds()")

        if options.get('timeout'):
            time = options['timeout'].get('time', 1)
            unit = options['timeout'].get('unit', 'HOURS')
            lines.append(f"        timeout(time: {time}, unit: '{unit}')")

        if options.get('retry'):
            count = options['retry']
            lines.append(f"        retry({count})")

        if options.get('timestamps'):
            lines.append("        timestamps()")

        if options.get('parallelsAlwaysFailFast'):
            lines.append("        parallelsAlwaysFailFast()")

        # New advanced options
        if options.get('preserveStashes'):
            build_count = options['preserveStashes'].get('buildCount', 5)
            lines.append(f"        preserveStashes(buildCount: {build_count})")

        if options.get('durabilityHint'):
            hint = options['durabilityHint']
            lines.append(f"        durabilityHint('{hint}')")

        if options.get('quietPeriod'):
            period = options['quietPeriod']
            lines.append(f"        quietPeriod({period})")

        if options.get('skipStagesAfterUnstable'):
            lines.append("        skipStagesAfterUnstable()")

        if options.get('disableResume'):
            lines.append("        disableResume()")

        if options.get('checkoutToSubdirectory'):
            subdir = options['checkoutToSubdirectory']
            lines.append(f"        checkoutToSubdirectory('{subdir}')")

        if options.get('newContainerPerStage'):
            lines.append("        newContainerPerStage()")

        lines.append("    }")
        return '\n'.join(lines)

    @staticmethod
    def triggers_block(triggers: Dict[str, str]) -> str:
        """Generate triggers block"""
        if not triggers:
            return ""

        lines = ["    triggers {"]

        if triggers.get('cron'):
            lines.append(f"        cron('{triggers['cron']}')")

        if triggers.get('pollSCM'):
            lines.append(f"        pollSCM('{triggers['pollSCM']}')")

        if triggers.get('upstream'):
            lines.append(f"        upstream(upstreamProjects: '{triggers['upstream']}', threshold: hudson.model.Result.SUCCESS)")

        lines.append("    }")
        return '\n'.join(lines)

    @staticmethod
    def tools_block(tools: Dict[str, str]) -> str:
        """Generate tools block"""
        if not tools:
            return ""

        lines = ["    tools {"]

        for tool_type, tool_name in tools.items():
            lines.append(f"        {tool_type} '{tool_name}'")

        lines.append("    }")
        return '\n'.join(lines)

    @staticmethod
    def when_block(conditions: Dict) -> str:
        """Generate when block for conditional stage execution"""
        if not conditions:
            return ""

        lines = ["            when {"]

        if conditions.get('branch'):
            lines.append(f"                branch '{conditions['branch']}'")

        if conditions.get('environment'):
            env_name = conditions['environment'].get('name')
            env_value = conditions['environment'].get('value')
            lines.append(f"                environment name: '{env_name}', value: '{env_value}'")

        if conditions.get('expression'):
            lines.append(f"                expression {{ {conditions['expression']} }}")

        if conditions.get('tag'):
            lines.append(f"                tag '{conditions['tag']}'")

        if conditions.get('not'):
            lines.append("                not {")
            for subcondition in conditions['not']:
                lines.append(f"                    {subcondition}")
            lines.append("                }")

        if conditions.get('allOf'):
            lines.append("                allOf {")
            for subcondition in conditions['allOf']:
                lines.append(f"                    {subcondition}")
            lines.append("                }")

        if conditions.get('anyOf'):
            lines.append("                anyOf {")
            for subcondition in conditions['anyOf']:
                lines.append(f"                    {subcondition}")
            lines.append("                }")

        lines.append("            }")
        return '\n'.join(lines)


class ScriptedSyntax:
    """Helper functions specific to Scripted Pipeline syntax"""

    @staticmethod
    def node_block(label: Optional[str] = None, content: str = "") -> str:
        """Generate node block"""
        if label:
            return f"""node('{label}') {{
{content}
}}"""
        else:
            return f"""node {{
{content}
}}"""

    @staticmethod
    def stage_block(name: str, content: str) -> str:
        """Generate stage block"""
        return f"""    stage('{name}') {{
{content}
    }}"""

    @staticmethod
    def try_catch_finally(try_content: str, catch_content: str = "", finally_content: str = "") -> str:
        """Generate try-catch-finally block"""
        blocks = [f"""    try {{
{try_content}
    }}"""]

        if catch_content:
            blocks.append(f"""    catch (Exception e) {{
{catch_content}
    }}""")

        if finally_content:
            blocks.append(f"""    finally {{
{finally_content}
    }}""")

        return '\n'.join(blocks)

    @staticmethod
    def parallel_block(parallel_stages: Dict[str, str]) -> str:
        """Generate parallel block"""
        stage_blocks = []
        for stage_name, stage_content in parallel_stages.items():
            stage_blocks.append(f"""        '{stage_name}': {{
{stage_content}
        }}""")

        return f"""    parallel(
{','.join(stage_blocks)}
    )"""

    @staticmethod
    def withEnv_block(env_vars: List[str], content: str) -> str:
        """Generate withEnv block"""
        env_list = ', '.join([f"'{var}'" for var in env_vars])
        return f"""    withEnv([{env_list}]) {{
{content}
    }}"""

    @staticmethod
    def docker_inside_block(image: str, content: str, args: str = "") -> str:
        """Generate docker.image().inside block"""
        if args:
            return f"""    docker.image('{image}').inside('{args}') {{
{content}
    }}"""
        else:
            return f"""    docker.image('{image}').inside {{
{content}
    }}"""


class ValidationHelpers:
    """Helper functions for validation"""

    @staticmethod
    def validate_stage_name(name: str) -> bool:
        """Validate stage name"""
        # Stage names should not be empty and should not contain special characters
        if not name or not name.strip():
            return False
        # Allow alphanumeric, spaces, hyphens, underscores
        return bool(re.match(r'^[a-zA-Z0-9\s\-_]+$', name))

    @staticmethod
    def validate_agent_type(agent_type: str) -> bool:
        """Validate agent type"""
        valid_types = ['any', 'none', 'label', 'docker', 'dockerfile', 'kubernetes']
        return agent_type.lower() in valid_types

    @staticmethod
    def validate_cron_expression(expression: str) -> bool:
        """Basic validation of cron expression"""
        # Should have 5 parts: MINUTE HOUR DOM MONTH DOW
        parts = expression.split()
        return len(parts) == 5

    @staticmethod
    def sanitize_pipeline_name(name: str) -> str:
        """Sanitize pipeline/job name for use in filenames"""
        # Replace special characters with hyphens
        sanitized = re.sub(r'[^a-zA-Z0-9\-_]', '-', name)
        # Remove multiple consecutive hyphens
        sanitized = re.sub(r'-+', '-', sanitized)
        # Remove leading/trailing hyphens
        sanitized = sanitized.strip('-')
        return sanitized.lower()


class FormattingHelpers:
    """Helper functions for formatting output"""

    @staticmethod
    def add_header_comment(content: str, description: str = "Generated Jenkinsfile") -> str:
        """Add header comment to Jenkinsfile"""
        header = f"""// {description}
// Generated by Jenkinsfile Generator
// Date: {FormattingHelpers.get_timestamp()}

"""
        return header + content

    @staticmethod
    def get_timestamp() -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    @staticmethod
    def indent_block(content: str, levels: int = 1) -> str:
        """Indent a block of text"""
        indent = '    ' * levels
        lines = content.split('\n')
        return '\n'.join([f"{indent}{line}" if line.strip() else '' for line in lines])

    @staticmethod
    def format_jenkinsfile(content: str) -> str:
        """Format Jenkinsfile with proper indentation and spacing"""
        # Remove excessive blank lines (3+ newlines -> 2 newlines)
        content = re.sub(r'\n{3,}', '\n\n', content)
        # Remove blank lines after opening braces
        content = re.sub(r'{\n\n(\s*)', r'{\n\1', content)
        # Remove blank lines before closing braces
        content = re.sub(r'\n\n(\s*})', r'\n\1', content)
        # Ensure proper spacing around blocks
        content = re.sub(r'}\n([a-zA-Z])', r'}\n\n\1', content)
        return content.strip() + '\n'