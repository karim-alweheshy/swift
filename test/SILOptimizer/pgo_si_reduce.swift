// RUN: %empty-directory(%t)
// RUN: %target-build-swift %s -profile-generate -Xfrontend -disable-incremental-llvm-codegen -module-name pgo_si_reduce -o %t/main

// RUN: %target-codesign %t/main
// RUN: env %env-LLVM_PROFILE_FILE=%t/default.profraw %target-run %t/main

// RUN: %llvm-profdata merge %t/default.profraw -o %t/default.profdata
// RUN: %target-swift-frontend %s -profile-use=%t/default.profdata -emit-sorted-sil -Xllvm -sil-print-types -emit-sil -module-name pgo_si_reduce -o - | %FileCheck %s --check-prefix=SIL
// RUN: %target-swift-frontend %s -profile-use=%t/default.profdata -O -emit-sorted-sil -Xllvm -sil-print-types -emit-sil -module-name pgo_si_reduce -o %t/output.sil -enable-noreturn-prediction -enable-throws-prediction -Xllvm --debug-only=cold-block-info 2> %t/debug.txt
// RUN: %FileCheck %s --check-prefix=SIL-OPT --input-file=%t/output.sil
// RUN: %FileCheck %s --check-prefix=COLD-BLOCKS --input-file=%t/debug.txt --implicit-check-not 'converged after {{[3-9]}} iters'

// REQUIRES: profile_runtime
// REQUIRES: executable_test
// REQUIRES: asserts

public func bar(_ x: Int32) -> Int32 {
  if (x == 0) {
    return 42
  }
  if (x == 1) {
    return 6
  }
  if (x == 2) {
    return 9
  }
  if (x % 2 == 0) {
    return 4242
  }
  var ret : Int32 = 0
  for currNum in stride(from: 5, to: x, by: 5) {
    ret += currNum
  }
  return ret
}

// SIL-LABEL: sil @$s13pgo_si_reduce3fooyys5Int32VF : $@convention(thin) (Int32) -> () !function_entry_count(1) {
// SIL-OPT-LABEL: sil @$s13pgo_si_reduce3fooyys5Int32VF : $@convention(thin) (Int32) -> () !function_entry_count(1) {
public func foo(_ x: Int32) {
  // SIL: switch_enum {{.*}} : $Optional<Int32>, case #Optional.some!enumelt: {{.*}} !case_count(100), case #Optional.none!enumelt: {{.*}} !case_count(1)
  // SIL: cond_br {{.*}}, {{.*}}, {{.*}} !true_count(50)
  // SIL: cond_br {{.*}}, {{.*}}, {{.*}} !true_count(1)
  // SIL-OPT: integer_literal $Builtin.Int32, 4242
  // SIL-OPT: integer_literal $Builtin.Int32, 42
  // SIL-OPT: function_ref @$s13pgo_si_reduce3barys5Int32VADF : $@convention(thin) (Int32) -> Int32
  
  var sum : Int32 = 0
  for index in 1...x {
    if (index % 2 == 0) {
      sum += bar(index)
    }
    if (index == 50) {
      sum += bar(index)
    }
    sum += 1
  }
  print(sum)
}
// SIL-LABEL: } // end sil function '$s13pgo_si_reduce3fooyys5Int32VF'
// SIL-OPT-LABEL: } // end sil function '$s13pgo_si_reduce3fooyys5Int32VF'

// Verify that cold block analysis correctly identifies blocks with zero or low profile counts.
//
// With profile data from foo(100) execution:
// - The loop executes from 1 to 100
// - index==50 is hit exactly once (low count, but not zero)
// - index%2==0 is hit 50 times (warm)
// - In bar(): x==0 is never hit (zero count), x%2==0 is hit 50 times (warm)
//
// Blocks with zero execution counts should be marked as cold.
// Blocks with very low counts relative to total should also be marked as cold.

// Verify the cold block analysis runs and produces output
// COLD-BLOCKS: ColdBlockInfo::analyze

foo(100)
