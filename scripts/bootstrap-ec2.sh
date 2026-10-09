#!/usr/bin/env bash
# Bootstrap an Ubuntu 24.04 EC2 instance for the Terraform testing lab.
# Installs: Terraform 1.12.2, TFLint v0.58.0, Checkov 3.2.443 (in a venv), make, jq, git.
set -euo pipefail

TERRAFORM_VERSION="1.12.2"
TFLINT_VERSION="v0.58.0"
CHECKOV_VERSION="3.2.443"

sudo apt-get update -y
sudo apt-get install -y gnupg software-properties-common curl unzip git jq make python3-venv lsb-release wget

# Terraform from the HashiCorp apt repository, pinned version
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y terraform=${TERRAFORM_VERSION}-1

# TFLint pinned version
curl -sLo tflint.zip "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip"
unzip -q tflint.zip -d /usr/local/bin
rm tflint.zip

# Checkov in an isolated virtualenv, pinned version
python3 -m venv "$HOME/.venvs/tflab"
"$HOME/.venvs/tflab/bin/pip" install --upgrade pip "checkov==${CHECKOV_VERSION}"
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.venvs/tflab/bin/checkov" "$HOME/.local/bin/checkov"

# Make sure the shell can see ~/.local/bin and cannot find any AWS credentials by accident
grep -q 'tflab-lab' "$HOME/.bashrc" || cat >> "$HOME/.bashrc" <<'EOF'

# tflab-lab
export PATH="$HOME/.local/bin:$PATH"
export AWS_EC2_METADATA_DISABLED=true
EOF

echo "--- versions ---"
terraform version
tflint --version
"$HOME/.local/bin/checkov" --version
