#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "Homebrew not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed"
fi

echo "Getting currently installed packages..."
# Get all installed packages into a file
brew list >/tmp/installed_packages.txt

echo "Checking which packages need to be installed..."
to_install=()
already_installed=()

# Read and process packages
while IFS= read -r package; do
    # Skip empty lines and comments
    if [[ -z "$package" ]] || [[ "$package" =~ ^#.* ]]; then
        continue
    fi

    # Trim whitespace
    package="${package%"${package##*[![:space:]]}"}"
    package="${package#"${package%%[![:space:]]*}"}"

    # Check if package exists in installed packages
    if grep -Fxq "$package" /tmp/installed_packages.txt; then
        already_installed+=("$package")
    else
        to_install+=("$package")
    fi
done <./macos/brew_packages.txt

# Clean up temporary file
rm /tmp/installed_packages.txt

# Install missing packages in parallel if there are any
if [ ${#to_install[@]} -eq 0 ]; then
    echo "All packages are already installed!"
else
    echo "Installing ${#to_install[@]} packages..."
    brew install "${to_install[@]}" &
    wait
    echo "Installation complete!"
fi
