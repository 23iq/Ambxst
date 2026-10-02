package main

import (
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestGenerateThumbVideo(t *testing.T) {
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		t.Skip("ffmpeg is required for video thumbnail generation")
	}
	dir := t.TempDir()
	srcPath := filepath.Join(dir, "video.mp4")
	cmd := exec.Command(ffmpeg, "-y", "-f", "lavfi", "-i",
		"testsrc2=size=160x90:rate=2", "-t", "2", "-c:v", "mpeg4", srcPath)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("create test video: %v\n%s", err, output)
	}
	thumbPath := filepath.Join(dir, "thumbnails", "video.mp4.jpg")
	if err := generateThumb(srcPath, thumbPath, 64); err != nil {
		t.Fatalf("generateThumb video: %v", err)
	}
	f, err := os.Open(thumbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	decoded, err := jpeg.Decode(f)
	if err != nil {
		t.Fatalf("video thumb not valid JPEG: %v", err)
	}
	bounds := decoded.Bounds()
	if bounds.Dx() != 64 || bounds.Dy() != 64 {
		t.Fatalf("expected 64x64 video thumb, got %dx%d", bounds.Dx(), bounds.Dy())
	}
}

func TestScaleCenterCrop(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 400, 200))
	out := scaleCenterCrop(src, 64)
	b := out.Bounds()
	if b.Dx() != 64 || b.Dy() != 64 {
		t.Fatalf("expected 64x64, got %dx%d", b.Dx(), b.Dy())
	}
}

func TestGenerateThumbImage(t *testing.T) {
	dir := t.TempDir()
	srcPath := filepath.Join(dir, "in.png")

	img := image.NewRGBA(image.Rect(0, 0, 100, 50))
	for y := 0; y < 50; y++ {
		for x := 0; x < 100; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x * 2), G: uint8(y * 4), B: 90, A: 255})
		}
	}
	f, err := os.Create(srcPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(f, img); err != nil {
		t.Fatal(err)
	}
	f.Close()

	thumbPath := filepath.Join(dir, "in.png.jpg")
	if err := generateThumbImage(srcPath, thumbPath, 32); err != nil {
		t.Fatalf("generateThumbImage: %v", err)
	}

	tf, err := os.Open(thumbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer tf.Close()

	decoded, err := jpeg.Decode(tf)
	if err != nil {
		t.Fatalf("thumb not valid jpeg: %v", err)
	}
	bounds := decoded.Bounds()
	if bounds.Dx() != 32 || bounds.Dy() != 32 {
		t.Fatalf("expected 32x32 thumb, got %dx%d", bounds.Dx(), bounds.Dy())
	}
}
