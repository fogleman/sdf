// Combine the PyCAM logo with a slightly depressed rounded-cornered box.

module block(a, b, height, radius) {
	translate([radius, radius, 0]) union() {
		translate([-radius, 0, 0]) cube([a, b - 2 * radius, height]);
		translate([0, -radius, 0]) cube([a - 2 * radius, b, height]);
		cylinder(r=radius, h=height);
		translate([a - 2 * radius, 0, 0]) cylinder(r=radius, h=height);
		translate([a - 2 * radius, b - 2 * radius, 0]) cylinder(r=radius, h=height);
		translate([0, b - 2 * radius, 0]) cylinder(r=radius, h=height);
	}
}

translate([0, 0, -10]) difference() {
	block(130, 50, 10, 10);
	translate([5, 5, 5]) block(120, 40, 6, 10);
}
translate([15, 17, -5.05]) linear_extrude(file="pycam-text.dxf", height=3);

