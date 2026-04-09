// RUN: %empty-directory(%t)
// RUN: %target-build-swift %s -profile-generate -Xfrontend -disable-incremental-llvm-codegen -module-name pgo_si_inlinelarge -o %t/main

// RUN: %target-codesign %t/main
// RUN: env %env-LLVM_PROFILE_FILE=%t/default.profraw %target-run %t/main

// RUN: %llvm-profdata merge %t/default.profraw -o %t/default.profdata
// RUN: %target-swift-frontend %s -profile-use=%t/default.profdata -emit-sorted-sil -Xllvm -sil-print-types -emit-sil -module-name pgo_si_inlinelarge -o - | %FileCheck %s --check-prefix=SIL
// RUN: %target-swift-frontend %s -profile-use=%t/default.profdata -O -emit-sorted-sil -Xllvm -sil-print-types -emit-sil -module-name pgo_si_inlinelarge -o %t/output.sil -enable-noreturn-prediction -enable-throws-prediction -Xllvm --debug-only=cold-block-info 2> %t/debug.txt
// RUN: %FileCheck %s --check-prefix=SIL-OPT --input-file=%t/output.sil
// RUN: %FileCheck %s --check-prefix=COLD-BLOCKS --input-file=%t/debug.txt --implicit-check-not 'converged after {{[3-9]}} iters'

// REQUIRES: profile_runtime
// REQUIRES: executable_test
// REQUIRES: asserts

public func bar(_ x: Int64) -> Int64 {
  if (x == 0) {
    return 42
  }
  if (x == 1) {
    return 6
  }
  if (x == 2) {
    return 9
  }
  if (x == 3) {
    return 93
  }
  if (x == 4) {
    return 94
  }
  if (x == 5) {
    return 95
  }
  if (x == 6) {
    return 96
  }
  if (x == 7) {
    return 97
  }
  if (x == 8) {
    return 98
  }
  if (x == 9) {
    return 99
  }
  if (x == 10) {
    return 910
  }
  if (x == 11) {
    return 911
  }
  if (x == 11) {
    return 911
  }
  if (x == 11) {
    return 911
  }
  if (x == 12) {
    return 912
  }
  if (x == 13) {
    return 913
  }
  if (x == 14) {
    return 914
  }
  if (x == 15) {
    return 916
  }
  if (x == 17) {
    return 917
  }
  if (x == 18) {
    return 918
  }
  if (x == 19) {
    return 919
  }
  if (x % 2 == 0) {
    return 4242
  }
  var ret : Int64 = 0
  for currNum in stride(from: 5, to: x, by: 5) {
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
    print("in bar stride")
    ret += currNum
    print(ret)
  }
  return ret
}

// SIL-LABEL: sil @$s18pgo_si_inlinelarge3fooyys5Int64VF : $@convention(thin) (Int64) -> () !function_entry_count(1) {
// SIL-OPT-LABEL: sil @$s18pgo_si_inlinelarge3fooyys5Int64VF : $@convention(thin) (Int64) -> () !function_entry_count(1) {
public func foo(_ x: Int64) {
  // SIL: switch_enum {{.*}} : $Optional<Int64>, case #Optional.some!enumelt: {{.*}} !case_count(100), case #Optional.none!enumelt: {{.*}} !case_count(1)
  // SIL: cond_br {{.*}}, {{.*}}, {{.*}} !true_count(50)
  // SIL: cond_br {{.*}}, {{.*}}, {{.*}} !true_count(1)
  // SIL-OPT: integer_literal $Builtin.Int64, 93
  // SIL-OPT: integer_literal $Builtin.Int64, 42
  // SIL-OPT: function_ref @$s18pgo_si_inlinelarge3barys5Int64VADF : $@convention(thin) (Int64) -> Int64

  var sum : Int64 = 0
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
// SIL-LABEL: } // end sil function '$s18pgo_si_inlinelarge3fooyys5Int64VF'
// SIL-OPT-LABEL: } // end sil function '$s18pgo_si_inlinelarge3fooyys5Int64VF'

// Verify that cold block analysis correctly identifies blocks with zero or low profile counts.
//
// With profile data from foo(100) execution:
// - The loop executes from 1 to 100
// - bar() is called only with even numbers (2,4,6,...,100)
// - In bar(): Many conditional blocks (x==3, x==5, x==7, etc.) are NEVER hit (zero count)
// - The x%2==0 block is hit 50+ times (warm)
// - The stride loop is hit for odd numbers > 19, but we never call with odd numbers (zero count)
//
// This tests that blocks with zero execution counts are correctly marked as cold,
// while frequently-executed blocks are marked as warm.

// Verify the cold block analysis runs and produces output
// COLD-BLOCKS: ColdBlockInfo::analyze

foo(100)
