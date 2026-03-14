import "dart:io"; void main() async { var r=await Process.run("cmd", ["/c","echo","hi"]); print(r.stdout); }
