# syntax=docker/dockerfile:1.7-labs

# Compile the Lambda binary
FROM public.ecr.aws/docker/library/golang:1.22-bullseye as builder
WORKDIR /app
COPY go.mod go.sum /app/
RUN go mod download
COPY lambda.go /app/
RUN go build -o /lambda

# Final build layer will use provided.al2023 as the base
FROM public.ecr.aws/lambda/provided:al2023

# Copy the relevant artifacts from the latest offline image
COPY --parents --from=ghcr.io/bored-engineer/trivy-offline:latest /usr/local/bin/trivy /contrib /root/.cache/trivy /

# Copy the Lambda binary from the builder stage and make it the entrypoint
COPY --from=builder /lambda /usr/local/bin/lambda
ENTRYPOINT [ "/usr/local/bin/lambda" ]
