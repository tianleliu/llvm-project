; RUN: opt -passes='default<O2>' -pgo-kind=pgo-sample-use-pipeline -profile-file='%S/Inputs/pm-ic-sc.prof' \
; RUN: %s -S 2>&1 |FileCheck %s

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; In SPGO mode, func4 would be inlined in func3, and func3 would be inlined in func2 in SampleProfileLoaderPass.
; After the inlining, func2()'s trunc and func4's sext will be transferred to shl(ashr),
; The transfer itself is ok, shl(ashr) at least not worse than sext(trunc),
; expecially in SIMD mode, vectorized shl(ashr)'s instructions are better than sext(trun),
; because trunc maps to PACK, which is heavier than SHIFT.
; But in this case, transferring icmp(sext_i32,sext_i32) to icmp_i8 in func4() is better for performance,
; especially func4() is very likely to be generated as SIMD instructions.
;The function level top-down order of visiting instructions in InstCombine makes the former IR has higher priority to be transferred than later IR.
; I don't blame the issue to InstCombine, and I think the root cause is we should do InstCombine and SimplifyCFG before SampleProfileLoaderPass's inlining. Because according to programmer’s coding logic, the combining/Simplifying chance inside a function should have higher priority than function’s outer.

; CHECK: vector.body:
; CHECK:    icmp sgt <32 x i8> %wide.load4, %broadcast.splat
; CHECK:    icmp sgt <32 x i8> %wide.load5, %broadcast.splat
; CHECK:    select <32 x i1> %9, <32 x i8> %wide.load, <32 x i8> zeroinitializer
; CHECK:    select <32 x i1> %10, <32 x i8> %wide.load3, <32 x i8> zeroinitializer

; CHECK-NOT  sext <32 x i8> %wide.load to <32 x i32>
; CHECK-NOT  sext <32 x i8> %wide.load3 to <32 x i32>
; CHECK-NOT  icmp slt <32 x i32> %broadcast.splat, %7
; CHECK-NOT  icmp slt <32 x i32> %broadcast.splat, %8
; CHECK-NOT  select <32 x i1> %9, <32 x i8> %wide.load, <32 x i8> zeroinitializer
; CHECK-NOT  select <32 x i1> %10, <32 x i8> %wide.load3, <32 x i8> zeroinitializer
define void @func1(ptr %array, ptr %min) #0 personality ptr null !dbg !3 {
  call void @func2(ptr %array, ptr %min), !dbg !6
  ret void
}

define void @func2(ptr %array, ptr %min) #0 personality ptr null !dbg !7 {
  %1 = load i32, ptr %min, align 4
  %2 = trunc i32 %1 to i8
  %3 = load volatile i32, ptr null, align 4
  call void @func3(ptr %array, i8 %2, i32 %3), !dbg !8
  ret void
}

define void @func3(ptr %0, i8 %1, i32 %2) #0 !dbg !10 {
  br label %4

4:                                                ; preds = %8, %3
  %5 = phi i32 [ 0, %3 ], [ %13, %8 ]
  %6 = icmp slt i32 %5, %2
  br i1 %6, label %8, label %7

7:                                                ; preds = %4
  ret void

8:                                                ; preds = %4
  %9 = zext i32 %5 to i64
  %10 = getelementptr i8, ptr %0, i64 %9
  %11 = load i8, ptr %10, align 1
  %12 = call i8 @func4(i8 %11, i8 %1), !dbg !11
  store i8 %12, ptr %10, align 1
  %13 = add i32 %5, 1
  br label %4
}

define i8 @func4(i8 %0, i8 %1) #0 !dbg !12 {
common.ret:
  %2 = sext i8 %0 to i32
  %3 = sext i8 %1 to i32
  %4 = icmp sgt i32 %2, %3
  %. = select i1 %4, i8 %0, i8 0
  ret i8 %.
}

; uselistorder directives
uselistorder ptr null, { 1, 3, 4, 0, 5, 6, 2 }

;attributes #0 = { "use-sample-profile" }
attributes #0 = { mustprogress uwtable "approx-func-fp-math"="true" "min-legal-vector-width"="0" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+avx,+avx2,+cmov,+crc32,+cx8,+fma,+fxsr,+mmx,+popcnt,+sse,+sse2,+sse3,+sse4.1,+sse4.2,+ssse3,+x87,+xsave" "tune-cpu"="generic" "unsafe-fp-math"="true" "use-sample-profile" }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2}

!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus_14, file: !1, producer: "clang version 20.0.0git (https://github.com/llvm/llvm-project.git 4d6e69143dc449814884ac649583d3b35bc4ae91)", isOptimized: true, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, debugInfoForProfiling: true, nameTableKind: None)
!1 = !DIFile(filename: "abc.cpp", directory: "")
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = distinct !DISubprogram(name: "func1", linkageName: "func1", scope: !1, file: !1, line: 104, type: !4, scopeLine: 105, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!4 = !DISubroutineType(types: !5)
!5 = !{}
!6 = !DILocation(line: 116, column: 7, scope: !3)
!7 = distinct !DISubprogram(name: "func2", linkageName: "func2", scope: !1, file: !1, line: 82, type: !4, scopeLine: 83, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!8 = !DILocation(line: 95, column: 3, scope: !9)
!9 = !DILexicalBlockFile(scope: !7, file: !1, discriminator: 2)
!10 = distinct !DISubprogram(name: "func3", linkageName: "func3", scope: !1, file: !1, line: 66, type: !4, scopeLine: 67, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!11 = !DILocation(line: 73, column: 19, scope: !10)
!12 = distinct !DISubprogram(name: "func4", linkageName: "func4", scope: !13, file: !13, line: 83, type: !4, scopeLine: 84, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!13 = !DIFile(filename: "", directory: "")
