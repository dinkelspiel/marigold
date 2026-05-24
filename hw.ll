@str = constant [14 x i8] c"Hello, World!\00"

declare i32 @puts(ptr)

define void @printme() {
  %i = alloca i32
  store i32 0, ptr %i
  br label %loop_start

loop_start:
  %i.val = load i32, ptr %i
  %1 = icmp eq i32 %i.val, 10
  br i1 %1, label %loop_exit, label %loop

loop:
  %i.old = load i32, ptr %i
  %i.new = add i32 %i.old, 1
  store i32 %i.new, ptr %i
  call i32 @puts(ptr @str)
  br label %loop_start

loop_exit:
  ret void
}

define void @main() {
  call void @printme() 
  ret void
}
