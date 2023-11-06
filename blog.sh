#!/bin/bash

# Update the system
sudo apt-get update && sudo apt-get -y dist-upgrade 

# Install Ruby
sudo apt-get install -y ruby-full build-essential zlib1g-dev whiptail

# Setup environment variables for ruby installation
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Jekyll and Bundler
gem install jekyll bundler

# Remove unused packages
sudo apt-get -y autoremove

# Ask for the name of the site
SITE_NAME=$(whiptail --inputbox "What should we call your blog?" 8 78 --title "Create your blog" 3>&1 1>&2 2>&3)

# Create the new Jekyll site
jekyll new $SITE_NAME

# Go to the directory
cd $SITE_NAME

# Start the Jekyll server in background
bundle exec jekyll serve --host=0.0.0.0 &
