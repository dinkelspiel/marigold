declare i32 @puts(ptr)
define void @aYbA9LBReWEd7xl8() {
%asd = alloca [5 x i8]
store [5 x i8] c"test\00", ptr %asd
%hw = alloca [12 x i8]
store [12 x i8] c"Hello World\00", ptr %hw
call i32 @puts(ptr %asd)
ret void
}
define void @a8jOO5ZUPAB8fl37() {
%i = alloca i32
store i32 0, ptr %i
br label %alrgu8NrI1dN1lgt_start
alrgu8NrI1dN1lgt_start:
%i.val = load i32, ptr %i
%1 = icmp eq i32 %i.val, 5
br i1 %1, label %alrgu8NrI1dN1lgt_exit, label %alrgu8NrI1dN1lgt
alrgu8NrI1dN1lgt:
%i.old = load i32, ptr %i
%i.new = add i32 %i.old, 1
store i32 %i.new, ptr %i
call void @aYbA9LBReWEd7xl8()
br label %alrgu8NrI1dN1lgt_start
alrgu8NrI1dN1lgt_exit:
ret void
}
define void @aK9PlUge9OIwxC3U() {
%i = alloca i32
store i32 0, ptr %i
br label %ah0gZv0bfuvZ90xf_start
ah0gZv0bfuvZ90xf_start:
%i.val = load i32, ptr %i
%1 = icmp eq i32 %i.val, 10
br i1 %1, label %ah0gZv0bfuvZ90xf_exit, label %ah0gZv0bfuvZ90xf
ah0gZv0bfuvZ90xf:
%i.old = load i32, ptr %i
%i.new = add i32 %i.old, 1
store i32 %i.new, ptr %i
call void @a8jOO5ZUPAB8fl37()
br label %ah0gZv0bfuvZ90xf_start
ah0gZv0bfuvZ90xf_exit:
ret void
}
define void @printme() {
call void @aK9PlUge9OIwxC3U()
ret void
}
define void @atD8eb6lGbugXfom() {
call i32 @printme()
ret void
}
define void @main() {
call void @atD8eb6lGbugXfom()
ret void
}
