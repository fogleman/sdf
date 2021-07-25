// example scene for pycam

module scene() {
    sphere(r=15, center=true);
    translate(v=[0,80,5]) cylinder(h = 10, r1 = 20, r2 = 10, center = true);
    translate(v=[0,40,15]) {
      intersection() {
        translate([0,0,-15]) rotate([60,0,90]) cube([30, 20, 20], center=true);
        cylinder(h = 30, r = 10, center = true);
      }
    }
    translate([0,130,-5]) {
      intersection() {
        sphere(20, center=true);
        rotate([30,60,0]) cube(30, center=true);
      }
    }
}

// remove the parts of the objects below the zero plane
difference() {
  scale([0.5, 0.5, 0.3]) scene();
  translate([0,0,-20]) cube([200,200,40], center=true);
}