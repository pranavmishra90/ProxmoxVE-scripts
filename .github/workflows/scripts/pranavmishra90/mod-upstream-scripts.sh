#!/bin/bash


DATE=$(date +%Y-%m-%d)
BRANCH_NAME="feat/update-$DATE"

SSH_KEY=$SSH_KEY

if ! ssh-add -l | grep -q "ED25519"; then
  echo "No SSH key found in agent. Trying to restart the ssh-agent."
  eval "$(ssh-agent -s)"
  ssh-add - <<< "${SSH_KEY}"
fi

if ! ssh-add -l | grep -q "ED25519"; then
  echo "No SSH key found in agent. Disabling commit signing."
  git config --global --unset user.signingkey
  git config --global --unset gpg.format
  git config --global --unset commit.gpgsign 
  git config --global --unset tag.gpgSign
else
  echo "SSH key found in agent. Enabling commit signing."
  git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDWKiAKIWUAAamY9AjUUCCE6yisHJpUowmpqhh9dJmQ Automated_Signature-Pranav_Mishra"
  git config --global gpg.format ssh
  git config --global commit.gpgsign true
fi

# git clone git@github.com:pranavmishra90/ProxmoxVE.git
git config advice.setUpstreamFailure false

git fetch origin main upstream
git checkout main

# Add upstream remote if it doesn't exist, otherwise ignore the error
git remote rm upstream || echo "upstream remote not found, adding it now"
git remote add upstream https://github.com/community-scripts/ProxmoxVE --no-tags -t main || echo "upstream remote already exists"
git remote set-url --push upstream no_push

# Create a new intermediate branch from the main branch
git checkout main
git checkout --no-track -B ${BRANCH_NAME} main


# Fetch the latest changes from the upstream repository into the upstream branch
git checkout upstream
git merge --quiet upstream/main -X ours

# Merge the upstream branch into the intermediate branch
git checkout ${BRANCH_NAME}
git merge --quiet upstream -X ours

# Delete the remote branch if it exists
git push origin -v --delete ${BRANCH_NAME} || echo "Remote branch ${BRANCH_NAME} does not exist."


# We expect to find merge conflicts here
# Resolve merge conflicts (if any) by keeping my fork's changes
if [ $? -ne 0 ]; then
    echo "[INFO] Merge conflicts detected. Resolving conflicts by keeping our changes."
    git add .
    git commit -m "ci: update repository with upstream changes"
fi

ERROR_COUNT=0
FILES=$(find . -name "*.sh" -o -name "*.func")

function fix_fork_urls() {
    local file="$1"
    if grep -q "githubusercontent.com/community-scripts/ProxmoxVE" "$file"; then
        sed -i 's|githubusercontent.com/community-scripts/ProxmoxVE|githubusercontent.com/pranavmishra90/ProxmoxVE|g' "$file"
        echo "[INFO] ✅ Updated URLs in: $file"
    fi
}

function check_executable() {
    local file="$1"
    if [[ ! -x "$file" ]]; then
        echo "[WARN] Shell script is not executable: $file"
        ERROR_COUNT=$((ERROR_COUNT + 1))

        # Make the script executable
        chmod +x "$file"
        echo "[INFO] ✅ Made script executable: $file"
    fi
}

function validate_changes() {
    local file="$1"
    fix_fork_urls "$file"
    check_executable "$file"
}

# First pass: Fix URLs
for FILE in $FILES; do
    fix_fork_urls "$FILE"
done

# Stage and commit URL fixes
if git diff --cached --exit-code; then
    echo "[INFO] No URL changes detected."
else
    git add .
    git commit -m "fix: update URLs to point to my fork"
fi

# Second pass: Fix executability
for FILE in $FILES; do
    check_executable "$FILE"
done

# Stage and commit executable fixes
if git diff --cached --exit-code; then
    echo "[INFO] No executable changes detected."
else
    git add .
    git commit -m "fix: made scripts executable"
fi

# Final validation
if [[ "$ERROR_COUNT" -gt 0 ]]; then
    echo "[WARN] $ERROR_COUNT script(s) were modified to our fork's settings."
    
    ERROR_COUNT=0
    for FILE in $FILES; do
        validate_changes "$FILE"
    done

    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo "[FATAL] $ERROR_COUNT script(s) failed validation."
        exit 1
    else
        echo "[INFO] All scripts passed validation."
        git add .
        git commit -m "ci: validation completed" --allow-empty-message
        git --no-pager log --decorate --show-pulls --no-show-signature --max-count 5 --abbrev-commit
    fi

else
    echo "[INFO] No changes were required after the upstream merge."
    git --no-pager log --decorate --show-pulls --no-show-signature --max-count 5 --abbrev-commit
fi

# Push the changes to the remote repository
git push -u origin ${BRANCH_NAME}
