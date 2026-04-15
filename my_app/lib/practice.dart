void main() {
  print("Welcome to dart");
  var stud = Student();
  stud.Details(101, "Shriya");

  var ad = myClass();
  print(ad.add(10, 12));
}

class myClass {
  myClass() {
    print("This is constructor of myClass");
  }
  int add(int a, int b) {
    return a + b;
  }
}

class Student {
  void Details(int roll, String name) {
    print("Roll No. :  : $roll");
    print("Name : $name");
  }
}
