ARG TRIVY_VERSION=0.49.1
FROM ghcr.io/aquasecurity/trivy:$TRIVY_VERSION AS trivy

# Download the trivy DBs using the trivy CLI, only need to run on the native platform
FROM --platform=$BUILDPLATFORM ghcr.io/aquasecurity/trivy:$TRIVY_VERSION as download

# https://aquasecurity.github.io/trivy/v0.49/docs/advanced/air-gap/
RUN trivy image --download-db-only && trivy image --download-java-db-only

# Compile the Lambda binary
FROM public.ecr.aws/docker/library/golang:1.22-bullseye as builder
WORKDIR /app
COPY go.mod go.sum /app/
RUN go mod download
COPY lambda.go /app/
RUN go build -o /lambda

# Final build layer
FROM public.ecr.aws/lambda/provided:al2023

# Copy the trivy CLI from the upstream official image
COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy

# Copy the downloaded trivy DBs from the download stage
COPY --from=download /root/.cache/trivy/ /airgap/

# Copy the Lambda binary from the builder stage
COPY --from=builder /lambda /usr/local/bin/lambda
ENTRYPOINT [ "/usr/local/bin/lambda" ]
