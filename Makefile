package:
	cd mongodb-org-server-raspberrypi \
	&& dpkg-deb --build ../mongodb-org-server-raspberrypi/ \
	&& cd .. \
	&& mv mongodb-org-server-raspberrypi.deb mongodb-org-server-raspberrypi_4.4.26_arm64.deb