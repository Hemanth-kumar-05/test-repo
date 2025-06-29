#!/usr/bin/env python3
import json
import subprocess

def main():
    # Load your JSON file
    with open("metadata.json", "r") as f:
        data = json.load(f)

    # Prepare the variables dictionary
    params = {}
    for item in data["params"]:
        param_name = item["param-name"]
        default_value = item["default-value"]
        params[param_name] = default_value

    # Prepare the -e arguments string
    extra_vars = []
    for k, v in params.items():
        # Important: For Windows paths, escape backslashes to double-backslashes
        if "\\" in v:
            v = v.replace("\\", "\\\\")
        extra_vars.append(f'{k}="{v}"')

    extra_vars_str = " ".join(extra_vars)

    # The playbook you want to run
    playbook = "win_cert_crawler.yml"

    # Build the ansible-playbook command
    command = f"ansible-playbook -i hosts.ini {playbook} -e '{extra_vars_str}'"

    print("Running command:")
    print(command)

    # Run the command
    result = subprocess.run(command, shell=True, capture_output=True, text=True)

    # Show output
    print("STDOUT:")
    print(result.stdout)
    print("STDERR:")
    print(result.stderr)

    if result.returncode != 0:
        print(f"Playbook failed with exit code {result.returncode}")
    else:
        print("Playbook completed successfully.")

if __name__ == "__main__":
    main()
