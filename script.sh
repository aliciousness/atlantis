#!/bin/sh
echo "This is so dumb they made a emphasis on the fact that the user is not root, "
echo "but to use atlantis user but the container image doesn't work with the atlantis user, "
echo "so I have to use root user to run the container..."
echo "I can't even change the ownership of the .atlantis directory because its not permitted to."
echo "So for now its just going to run as root... whatever"
echo ""
echo "Oh! btw this script is originally used as an entrypoint script for the atlantis container"
echo "but I have nothing to do before starting the server so I'm just leaving you a message here."
echo ""
# echo "Set ownership of atlantis home directory"
# chown -R atlantis:atlantis /home/atlantis