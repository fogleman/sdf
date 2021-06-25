package main

import (
	"fmt"
	go_image "image"
	"log"
	"os"
	"path"
	"strings"
	"time"

	. "github.com/fogleman/fauxgl"
	"github.com/nfnt/resize"
	"github.com/oliamb/cutter"
)

const (
	aa     = 4
	width  = 1024
	height = 1024
	near   = 1
	far    = 10
)

var (
	eye    = V(3, 3, 3)
	center = V(0, 0, 0)
	up     = V(0, 0, 1)

	axisLight  = V(1, 1, 1)
	modelLight = V(0.75, 0.25, 1)

	xColor      = HexColor("BF1506")
	yColor      = HexColor("5ABF56")
	zColor      = HexColor("1B52BF")
	originColor = HexColor("333333")
	modelColor  = HexColor("2185C5")

	background = Transparent

	showAxis = true
)

func main() {
	// parse command line arguments
	args := os.Args[1:]
	if len(args) != 2 {
		log.Fatal("Usage: go run render.go input.stl output.png")
	}

	if strings.HasPrefix(path.Base(os.Args[1]), "2d_") {
		fmt.Println("Using 2d perspective")
		eye = V(0, 0, 4)
		center = V(0, 0, 0)
		up = V(0, 1, 0)
		modelLight = V(0.5, 0.5, 2).Normalize()
		showAxis = false
		//eye = V(1.5, 1.5, 3)
		//up = V(1, 0, 0)
		//center = V(.5, .5, 0)
		//zColor = Transparent
	}

	// load mesh
	mesh, err := LoadMesh(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}

	// scale mesh to fit in a bi-unit cube centered at the origin
	// but do not translate it
	box := mesh.BoundingBox()
	h := box.Max.Abs().Max(box.Min.Abs())
	s := V(1, 1, 1).Div(h).MinComponent()
	mesh.Transform(Scale(V(s, s, s)))

	// create rendering context
	context := NewContext(width*aa, height*aa)
	context.ClearColorBufferWith(background)

	// create transformation matrix
	matrix := LookAt(eye, center, up)
	matrix = matrix.Orthographic(-2, 2, -2, 2, near, far)

	// render axes and origin
	if showAxis {
		shader := NewPhongShader(matrix, axisLight.Normalize(), eye)
		shader.AmbientColor = Gray(0.4)
		shader.DiffuseColor = Gray(0.7)
		shader.SpecularColor = Gray(0)
		context.Shader = shader

		axes := []Vector{
			V(1, 0, 0),
			V(0, 1, 0),
			V(0, 0, 1),
		}

		colors := []Color{xColor, yColor, zColor}

		for i, axis := range axes {
			shader.ObjectColor = colors[i]

			c := NewCylinder(30, false)
			c.Transform(Scale(V(0.01, 0.01, 2)))
			c.Transform(Translate(V(0, 0, 1)))
			c.Transform(RotateTo(up, axis))
			c.SmoothNormals()
			context.DrawMesh(c)

			c = NewCone(30, false)
			c.Transform(Scale(V(0.03, 0.03, 0.1)))
			c.Transform(Translate(V(0, 0, 2)))
			c.Transform(RotateTo(up, axis))
			c.SmoothNormals()
			context.DrawMesh(c)
		}

		shader.ObjectColor = originColor
		c := NewSphere(2)
		c.Transform(Scale(V(0.025, 0.025, 0.025)))
		c.SmoothNormals()
		context.DrawMesh(c)
	}

	// render mesh
	{
		shader := NewPhongShader(matrix, modelLight.Normalize(), eye)
		shader.ObjectColor = modelColor
		shader.AmbientColor = Gray(0.3)
		shader.DiffuseColor = Gray(0.9)
		shader.SpecularColor = Gray(0.2)
		shader.SpecularPower = 10
		context.Shader = shader
		start := time.Now()
		info := context.DrawMesh(mesh)
		fmt.Println(info)
		fmt.Println(time.Since(start))
	}

	// save image
	image := context.Image()
	image = resize.Resize(width, height, image, resize.Bilinear)

	// crop off 2d images
	if strings.HasPrefix(path.Base(os.Args[1]), "2d_") {
		bounds := image.Bounds()
		minY := bounds.Min.Y
		maxY := bounds.Max.Y
		minX := bounds.Min.X
		maxX := bounds.Max.X
		for has_image := false; minY < maxY && !has_image; minY++ {
			for i := minX; i < maxX; i++ {
				_, _, _, A := image.At(i, minY).RGBA()
				has_image = has_image || (A != 0)
			}
		}
		for has_image := false; minY < maxY && !has_image; maxY-- {
			for i := maxX - 1; i >= minX; i-- {
				_, _, _, A := image.At(i, maxY).RGBA()
				has_image = has_image || (A != 0)
			}
		}
		for has_image := false; minX < maxX && !has_image; minX++ {
			for i := minY; i < maxY; i++ {
				_, _, _, A := image.At(minX, i).RGBA()
				has_image = has_image || (A != 0)
			}
		}
		for has_image := false; minX < maxX && !has_image; maxX-- {
			for i := maxY - 1; i >= minY; i-- {
				_, _, _, A := image.At(maxX, i).RGBA()
				has_image = has_image || (A != 0)
			}
		}
		//fmt.Println("minX", minX, "minY", minY, "maxX", maxX, "maxY", maxY)

		image, _ = cutter.Crop(image, cutter.Config{
			Width:  maxX - minX + 2,
			Height: maxY - minY + 2,
			Anchor: go_image.Point{minX - 1, minY - 1},
			Mode:   cutter.TopLeft, // optional, default value
		})
	}
	SavePNG(os.Args[2], image)
}
