# Packaging

Create your debian package:

`make package`

or:

1. Extract the binaries you compiled into ./mongodb-org-server_raspberrypi/usr/local/bin
2. cd /mongodb-org-server-raspberrypi/usr/local/bin
3. dpkg-deb --build ../mongodb-org-server-raspberrypi/
4. Inspect the package: dpkg -c ../mongodb-org-server-raspberrypi.deb
5. Rename the .deb file to include version and architecture: mv mongodb-org-server-raspberrypi.deb mongodb-org-server-raspberrypi_4.4.26_arm64.deb