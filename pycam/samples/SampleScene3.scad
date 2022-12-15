difference() {
	sphere(r=30);
	translate([-50, -50, -100]) cube([100, 100, 100]);
}

translate([-30, 50, 0]) union() {
	cube([140, 30, 10]);
	translate([40, 15, 10]) rotate([0, 90, 0]) cylinder(r=10, h=60);
}

translate([80, 0, 0]) scale(1.2) union() {
	difference() {
		cylinder(r1=20, r2=5, h=20);
		translate([-25, 30, -10]) rotate([60, 0, 0]) cube([50, 50, 50]);
	}
	difference() {
		translate([0, 35, -21]) rotate([70, 0, 0]) cylinder(r=16, h=50);
		translate([-50, -50, -100]) cube([100, 100, 100]);
	}
}