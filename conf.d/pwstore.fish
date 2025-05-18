# Initialize the password store at startup

# This file ensures the password store directory exists
if not test -d $XDG_CONFIG_HOME/fish/secure/passwords
    mkdir -p $XDG_CONFIG_HOME/fish/secure/passwords
end
