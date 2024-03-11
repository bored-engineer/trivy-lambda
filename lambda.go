package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/aws/aws-lambda-go/lambda"
)

// result is the structure of the JSON response
type result struct {
	StdErr   string `json:"stderr,omitempty"`
	StdOut   string `json:"stdout,omitempty"`
	ExitCode int    `json:"exitcode,omitempty"`
	Output   string `json:"output,omitempty"`
}

func invoke(ctx context.Context, args []string) (*result, error) {
	// Runs 'trivy ...' capturing the stderr/stdout
	cmd := exec.CommandContext(ctx, "trivy", args...)
	cmd.Env = os.Environ()
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	// Create a new temporary directory for the Trivy cache for this invocation
	// We will remove it after the invocation to avoid filling up the /tmp directory
	tmpDir, err := os.MkdirTemp(os.Getenv("TRIVY_TMP"), "trivy-cache-*")
	if err != nil {
		return nil, fmt.Errorf("os.MkdirTemp failed: %w", err)
	}
	defer os.RemoveAll(tmpDir)
	cmd.Env = append(cmd.Env, fmt.Sprintf("TRIVY_CACHE_DIR=%s", tmpDir))
	cmd.Env = append(cmd.Env, fmt.Sprintf("TMPDIR=%s", tmpDir))
	outputFile := filepath.Join(tmpDir, "output")
	cmd.Env = append(cmd.Env, fmt.Sprintf("TRIVY_OUTPUT=%s", outputFile))

	// Symlink the air-gapped DBs from the image layers to the cache directory and disable auto-update
	offlineCacheDir := "/root/.cache/trivy"
	for _, directory := range []string{"policy", "java-db", "db"} {
		src, dst := filepath.Join(offlineCacheDir, directory), filepath.Join(tmpDir, directory)
		if err := os.Symlink(src, dst); err != nil {
			return nil, fmt.Errorf("os.Symlink from %q to %q failed: %w", src, dst, err)
		}
	}

	// Execute, capturing the exit-code if any
	var r result
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			r.ExitCode = exitErr.ExitCode()
		} else {
			return nil, fmt.Errorf("cmd.Run failed: %w", err)
		}
	}
	r.StdOut = stdout.String()
	r.StdErr = stderr.String()

	// Read the output file if exists
	if b, err := os.ReadFile(outputFile); err == nil {
		r.Output = string(b)
	} else if !os.IsNotExist(err) {
		return nil, fmt.Errorf("os.ReadFile failed: %w", err)
	}

	return &r, nil
}

func main() {
	lambda.Start(invoke)
}
