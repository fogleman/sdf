package main

import (
	"fmt"
	"log"
	"os"
	"time"

	. "github.com/fogleman/fauxgl"
	"github.com/nfnt/resize"
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
)

func main() {
	// parse command line arguments
	args := os.Args[1:]
	if len(args) != 2 {
		log.Fatal("Usage: go run render.go input.stl output.png")
	}

	// load mesh
	mesh, err := LoadMesh(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}

	// fit mesh in a bi-unit cube centered at the origin
	mesh.BiUnitCube()

	// create rendering context
	context := NewContext(width*aa, height*aa)
	context.ClearColorBufferWith(background)

	// create transformation matrix
	matrix := LookAt(eye, center, up)
	matrix = matrix.Orthographic(-2, 2, -2, 2, near, far)

	// render axes and origin
	{
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
	SavePNG(os.Args[2], image)
}
