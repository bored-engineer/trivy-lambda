# Compile the Lambda binary
FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.22.1-bullseye as builder
WORKDIR /src
COPY go.mod go.sum /src/
RUN go mod download
COPY lambda.go /src/
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /lambda

# Final build layer will use provided.al2023 as the base
FROM public.ecr.aws/lambda/provided:al2023

# Copy the trivy CLI and DB artifacts from the latest offline image
COPY --from=ghcr.io/bored-engineer/trivy-offline:latest /usr/local/bin/trivy /usr/local/bin/trivy
ENV TRIVY_OFFLINE_SCAN=true
ENV TRIVY_SKIP_POLICY_UPDATE=true
ENV TRIVY_SKIP_JAVA_DB_UPDATE=true
ENV TRIVY_SKIP_DB_UPDATE=true
COPY --chmod=777 --from=ghcr.io/bored-engineer/trivy-offline:latest /root/.cache/trivy /offline

# Copy the Lambda binary from the builder stage and make it the entrypoint
COPY --from=builder /lambda /usr/local/bin/lambda
ENTRYPOINT [ "/usr/local/bin/lambda" ]
