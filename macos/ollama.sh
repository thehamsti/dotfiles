#!/bin/sh

# Check if Ollama is already installed
if ! command -v ollama &> /dev/null; then
    echo "Ollama not installed. Downloading and installing Ollama..."
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit
    
    # Download Ollama
    echo "Downloading Ollama..."
    curl -L https://ollama.com/download/Ollama-darwin.zip -o Ollama.zip
    
    # Unzip the application
    echo "Extracting Ollama..."
    unzip -q Ollama.zip
    
    # Move to Applications folder
    echo "Installing Ollama to Applications folder..."
    mv Ollama.app /Applications/
    
    # Clean up
    cd - || exit
    rm -rf "$temp_dir"
    
    echo "Ollama has been installed to your Applications folder"
    echo "You can now launch Ollama from your Applications folder"
else
    echo "Ollama is already installed"
fi

# Optional: Check if Ollama service is running
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama service..."
    open -a Ollama
else
    echo "Ollama service is already running"
fi

echo "Installation complete! You can now use Ollama"
echo "To pull a model, use: ollama pull <model-name>"
echo "To run a model, use: ollama run <model-name>"
