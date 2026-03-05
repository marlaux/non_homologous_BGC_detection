import re
import sys

def validate_rule_file(file_path):
    """
    Validate the syntax of rules in the given file.

    Args:
        file_path (str): Path to the rule file.

    Returns:
        None
    """
    with open(file_path, 'r') as file:
        lines = file.readlines()

    errors = []
    rule_pattern = re.compile(r'^RULE\s+\w+')
    cds_pattern = re.compile(r'cds\((.*?)\)')

    # Combine broken lines in CONDITIONS and EXTENDERS into one logical line
    combined_lines = []
    for line in lines:
        if combined_lines and (combined_lines[-1].strip().endswith('and') or combined_lines[-1].strip().endswith('or') or combined_lines[-1].strip().endswith('(')):
            combined_lines[-1] = combined_lines[-1].strip() + ' ' + line.strip()
        else:
            combined_lines.append(line)

    for line_number, line in enumerate(combined_lines, start=1):
        # Skip comment lines
        if line.strip().startswith('#'):
            continue

        # Ignore 'or' in DESCRIPTION and EXAMPLE lines
        if 'DESCRIPTION' in line or 'EXAMPLE' in line:
            continue

        # Ignore 'or' when the word is 'cofactor' or 'precursor'
        if 'cofactor' in line or 'precursor' in line:
            continue

        # Skip lines that are clearly not part of CONDITIONS or EXTENDERS
        if 'NEIGHBOURHOOD' in line:
            continue

        # Refine unmatched parentheses check to consider multi-line CONDITIONS and EXTENDERS
        if 'cds(' in line:
            open_parentheses = line.count('(')
            close_parentheses = line.count(')')
            if open_parentheses > close_parentheses:
                # Check subsequent lines for closing parentheses
                for next_line in combined_lines[line_number:]:
                    open_parentheses += next_line.count('(')
                    close_parentheses += next_line.count(')')
                    if open_parentheses == close_parentheses:
                        break
                else:
                    errors.append(f"Line {line_number}: Unmatched parentheses in 'cds' condition.")

        # Check for missing operators
        if ' or ' not in line and ' and ' not in line and 'not ' not in line and 'cds(' in line:
            cds_match = cds_pattern.search(line)
            if cds_match:
                conditions = cds_match.group(1).split()
                if len(conditions) > 1:
                    errors.append(f"Line {line_number}: Missing logical operators in 'cds' condition.")

        # Check for repeated conditions
        if 'cds(' in line:
            cds_match = cds_pattern.search(line)
            if cds_match:
                conditions = cds_match.group(1).split(' or ')
                seen_conditions = set()
                for condition in conditions:
                    if condition in seen_conditions:
                        errors.append(f"Line {line_number}: Rule contains repeated condition '{condition}'.")
                    seen_conditions.add(condition)

        # Check for concatenated 'or' only as suffix or prefix
        if re.search(r'(\bor\w+|\w+or\b)', line):
            errors.append(f"Line {line_number}: Logical operator 'or' concatenated as suffix or prefix.")

        # Check for repeated 'and' or 'or' in sequence
        if 'and and' in line or 'or or' in line:
            errors.append(f"Line {line_number}: Repeated logical operators found.")

        # Check for repeated logical operators within and across lines
        if 'and' in line or 'or' in line:
            tokens = line.strip().split()
            for i in range(len(tokens) - 1):
                if tokens[i] in {'and', 'or'} and tokens[i] == tokens[i + 1]:
                    errors.append(f"Line {line_number}: Repeated logical operator '{tokens[i]}'.")

            # Adjust line number reporting for repeated logical operators across lines
            if line_number > 1:
                previous_line = combined_lines[line_number - 2]
                if previous_line.strip().endswith(('and', 'or')) and tokens[0] in {'and', 'or'}:
                    errors.append(f"Line {line_number}: Repeated logical operator '{tokens[0]}'.")

    if errors:
        print("Validation Errors:")
        for error in errors:
            print(error)
    else:
        print("No syntax errors found in the rule file.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python validate_rules.py <path_to_rule_file>")
        sys.exit(1)

    rule_file_path = sys.argv[1]
    validate_rule_file(rule_file_path)