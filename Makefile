CURRENT_VERSION=0.0.1

all:
	docker build -t untoldone/scp-ocr-upload:latest .
	docker tag untoldone/scp-ocr-upload:latest untoldone/scp-ocr-upload:$(CURRENT_VERSION)

push:
	docker push untoldone/scp-ocr-upload:latest
	docker push untoldone/scp-ocr-upload:$(CURRENT_VERSION)
