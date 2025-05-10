#!/bin/bash


DATE=$(date +%Y-%m-%d)
BRANCH_NAME="feat/update-$DATE"

cd ProxmoxVE

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
git merge upstream/main -X ours

# Merge the upstream branch into the intermediate branch
git checkout ${BRANCH_NAME}
git merge upstream -X ours

# We expect to find merge conflicts here
# Resolve merge conflicts (if any) by keeping my fork's changes
if [ $? -ne 0 ]; then
    echo "[INFO] Merge conflicts detected. Resolving conflicts by keeping our changes."
    git add .
    git commit -m "ci: update repository with upstream changes"
fi

ERROR_COUNT=0
FILES=$(find . -name "*.sh")

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
