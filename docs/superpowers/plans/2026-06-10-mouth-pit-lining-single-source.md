# 입 구덩이 음영 단일 출처화 구현 계획 (MouthCavity를 머리 메쉬 파이프라인에서 생성)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 위턱 카브/입 구덩이를 덮는 검은 음영(`MouthCavity`)이 깨지고 어긋나는 문제를 해결한다. 음영이 ① 입 안 패임에 정확히 맞고 ② 입 밖(실루엣 바깥)으로 튀어나오지 않으며 ③ 아래턱 쪽 음영(`MouthFloor`)과 틈 없이 이어지게 한다.

**Architecture:** 근본 원인은 `FishRig._mouth_pit_dark_mesh`가 머리 표면을 수식으로 복제 근사하는 것이다(주둥이 테이퍼·등선/배선·범프·방향별 평면화를 반영하지 않는 `_head_front_surface_x`, 순수 구를 역산하는 `u_base`, 최근접 정점 클램프 `_head_mesh_front_x`의 계단 현상). 해결은 복제를 제거하고 음영 메쉬를 `PrimitiveFactory.deformed_head_mesh`와 **같은 정점별 변형 체인**에서 직접 방출하는 것이다: 정점 체인을 공유 헬퍼로 추출하고, 구덩이 가중치(`HeadProfile.mouth_pit_weight`)가 0보다 큰 그리드 셀만 모아 살짝 띄운 안감 메쉬를 만든다. 띄움량을 가중치에 비례시키면 구덩이 가장자리에서 자동으로 0이 되어 실루엣 밖으로 절대 나가지 않는다. 아래턱 연결부는 맞대기(butt-joint) 대신 같은 어두운 재질끼리 의도적으로 겹쳐 틈을 없앤다.

**Tech Stack:** Godot 4 GDScript, `tools/run_godot_cli_tests.ps1`, 육안 확인은 기존 `scripts/tools/MouthShot.gd`(비-headless) 패턴.

**전제:** `codex/directional-body-head-sculpt-controls` 브랜치의 방향별 평면화(`head_*_flatness`, `_head_point_before_flatness` 헬퍼)가 존재하는 상태 기준.

## 사전 조건 (필수 — 작업 시작 전)

이 계획은 `scripts/creature/FishRig.gd`, `scripts/creature/PrimitiveFactory.gd`를 수정하는데, 현재 작업 트리에 방향별 스컬프트 작업이 같은 파일들의 미커밋 변경으로 남아 있을 수 있다. 그대로 진행하면 Task별 커밋에 무관한 변경이 섞인다.

- [ ] `git status --short` 실행. 이 계획이 수정하는 파일에 미커밋 변경이 있으면 **둘 중 하나를 먼저 수행**: ① 기존 변경을 해당 기능 커밋으로 마무리(방향별 스컬프트 변경은 그 브랜치의 본래 작업이므로 선커밋이 자연스럽다), 또는 ② 이 계획 전용 브랜치/worktree를 새로 만들어 깨끗한 상태에서 시작.
- [ ] 위 정리 후 `git status --short`에서 이 계획의 대상 파일이 깨끗한지 재확인하고 나서 Task 1을 시작한다.

---

## Scope Contract

- `deformed_head_mesh`의 기하 출력은 리팩터링 전후 동일해야 한다. 정점 체인을 헬퍼로 추출하는 것은 순수 코드 이동이며, 기존 `HeadEditorModelTest`/`HeadShellSeamTest`의 기하 assert가 그대로 통과해야 한다.
- 안감 메쉬의 모든 정점은 같은 (phi, theta) 그리드 인덱스의 머리 메쉬 정점에서 **띄움량(≤ 0.004) 이내** 거리에 있어야 한다. 별도의 표면 근사·정점 클램프를 다시 도입하지 않는다.
- 띄움량은 **실제 패임량으로 캡**한다: `outset = minf(proud * pit_weight, pit_inset_x * 0.45)`. 패임량(`HeadProfile.mouth_pit_offset`의 x 성분)은 `depth * gape * weight`로 게이프에 비례하므로, 고정 `proud * weight`만 쓰면 작은 `mouth_open`(스폰 임계 0.01 직후 ~0.036 구간)에서 띄움이 패임을 초과해 원래 표면 밖으로 나온다. 캡 덕에 림(가중치 0) 정점은 셸과 일치하고, 내부 정점은 어떤 게이프·스컬프트 조합에서도 패임의 45% 이내에만 떠 있어 바깥 실루엣을 뚫지 않는다. (게이프가 아주 작을 때 안감-셸 간격이 서브픽셀이 되어 의미가 없어지는 것은 허용 — 그 구간에선 패임 자체가 보이지 않는다.)
- `mouth_open <= 0.01`이면 `MouthCavity`가 생성되지 않는 기존 동작 유지 (구덩이 자체가 게이프 0에서 사라지므로).
- 입 모양 틸트(`_mouth_angle_for_type`)는 안감에 적용하지 않는다 — 머리 메쉬의 패임(블록 6c) 자체가 틸트되지 않으므로, 기존 `_mouth_pit_dark_mesh`의 틸트 회전은 근사의 일부였을 뿐이다.
- `_mouth_upper_interior_mesh`, `_mouth_side_aperture_mesh`, `_mouth_band_mesh`는 이 계획의 범위 밖이다(동일한 최근접 정점 클램프 문제를 갖고 있으나 후속 작업). 단, 이번에 만드는 공유 헬퍼는 이들이 재사용할 수 있는 형태여야 한다.
- 머리/셸 이음새 계약 불변: `HeadShellSeamTest`의 `_max_escape` 한계를 깨지 않는다.

## File Structure

- Modify `scripts/creature/PrimitiveFactory.gd`: 정점 체인 헬퍼 `_head_final_point` 추출, `mouth_pit_lining_mesh` 신설, `deformed_head_mesh`가 헬퍼 경유하도록 변경.
- Modify `scripts/creature/FishRig.gd`: `MouthCavity` 생성을 새 함수로 교체, `_mouth_pit_dark_mesh` 및 전용 중복 계산 삭제, `MouthFloor` 겹침 보정.
- Add `scripts/tools/MouthCavityFitTest.gd` + `scenes/MouthCavityFitTest.tscn`: 안감-셸 밀착 회귀 테스트.
- Modify `scripts/tools/MouthShot.gd`: 스컬프트 적용 샷 추가(육안 확인용, 스위트 제외 도구).

---

### Task 1: 밀착 회귀 테스트 작성 (현재 코드로 실패 입증)

**Files:** `scripts/tools/MouthCavityFitTest.gd`, `scenes/MouthCavityFitTest.tscn`

- [ ] **Step 1: 테스트 작성.** `MouthCavityFitTest.gd`: FishRig를 만들고 음영이 어긋나는 공격적 스컬프트 조합을 적용:

```gdscript
var params := {
	"shell_enabled": 1.0,
	"head_shape": "rounded",
	"snout_length": 0.45,
	"snout_taper": 0.7,
	"snout_thickness": 0.6,
	"head_belly_curve": -0.7,
	"head_bottom_flatness": 0.8,
	"head_bump_height": 0.3,
	"mouth_open": 1.0,
	"mouth_size": 0.14,
}
```

  assert 항목 (모두 head-local 좌표로 비교 — `MouthCavity`와 `Head`의 상대 변환을 반영해 정점을 같은 공간으로 옮길 것):
  - `BodyPivot/Head/MouthCavity`가 존재한다.
  - cavity 모든 정점에 대해 머리 메쉬 정점 중 최근접 거리 `< 0.02` (밀착 — 현재 코드는 평면화·테이퍼 조합에서 이를 크게 초과해 실패해야 한다).
  - cavity 모든 정점에 대해 최근접 머리 정점보다 `0.006` 이상 앞(-x)에 있지 않다 (튀어나옴 금지).
  - `mouth_open: 0.0`으로 재설정하면 `MouthCavity`가 없다.
  - 통과 시 `print("MOUTH_CAVITY_FIT_TEST_OK")` + `exports/test_results/mouth_cavity_fit.ok` 기록 후 `quit(0)` (기존 테스트 관례).
- [ ] **Step 2: 실패 확인.** `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MouthCavityFitTest` — 밀착 assert에서 실패해야 한다. (만약 통과한다면 스컬프트 값을 더 키워 현상을 재현한 뒤 진행 — 사용자가 실제로 깨짐을 관찰한 상태다.)
- [ ] **Step 3: 커밋.** 테스트 + tscn + `.uid` → `git commit -m "Add failing mouth cavity fit regression test"`

### Task 2: PrimitiveFactory 정점 체인 헬퍼 추출 (순수 리팩터링)

**Files:** `scripts/creature/PrimitiveFactory.gd`

- [ ] **Step 1: 헬퍼 추출.** `deformed_head_mesh`의 그리드 루프 본문(현재 1→2→3→4→4b→4c→5→평면화→6→6b→6c 단계, 약 144~263행)을 정적 헬퍼로 이동:

```gdscript
# Returns {"point": Vector3, "pit_weight": float, "pit_inset_x": float} for one
# (phi, theta) grid sample. pit_weight is the HeadProfile.mouth_pit_weight used in
# block 6c (0.0 when gape == 0 or shape == "cephalofoil") and pit_inset_x is the
# actual +x dent applied there (maxf(pit.x, 0.0)), so callers can identify the carved
# socket region AND know how deep each vertex was pushed in.
static func _head_final_point(shape: String, phi: float, theta: float, snout_length: float, forehead_slope: float, sculpt: Dictionary, precomputed: Dictionary) -> Dictionary:
```

  - `precomputed`에는 루프 밖에서 한 번만 계산하던 값(`jaw_lm`, `premax_fwd`, 카브/구덩이 스케일, 평면화 값, 범프 삼각함수 등)을 담아 정점마다 재계산하지 않는다. 이 사전 계산도 `_head_mesh_precompute(shape, snout_length, forehead_slope, sculpt) -> Dictionary` 헬퍼로 추출한다.
  - 블록 6c에서 `HeadProfile.mouth_pit_offset` 호출 시 같은 인자로 `mouth_pit_weight`도 구하고, 적용한 패임의 x 성분(`maxf(pit.x, 0.0)`)을 `pit_inset_x`로 함께 반환 딕셔너리에 담는다.
  - 평면화 단계가 쓰는 `_head_point_before_flatness` 4방향 타깃 샘플은 기존 코드 그대로 유지.
- [ ] **Step 2: `deformed_head_mesh`를 헬퍼 경유로 교체.** 그리드 루프는 `_head_final_point(...)["point"]`만 사용. 수치 결과가 달라질 변형(연산 순서 변경, clamp 추가 등)을 일절 하지 않는다.
- [ ] **Step 3: 회귀 확인.** 기하를 검증하는 기존 테스트 전부 통과 확인:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeamTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadDiagnosticTraitTest
```

- [ ] **Step 4: 커밋.** `"Extract shared head vertex pipeline helper"`

### Task 3: mouth_pit_lining_mesh 구현 + FishRig 교체

**Files:** `scripts/creature/PrimitiveFactory.gd`, `scripts/creature/FishRig.gd`

- [ ] **Step 1: 안감 생성기.** `PrimitiveFactory`에 추가:

```gdscript
static func mouth_pit_lining_mesh(shape: String, snout_length: float, forehead_slope: float, rings: int, segments: int, sculpt: Dictionary, proud: float = 0.004) -> ArrayMesh:
```

  - `deformed_head_mesh`와 **동일한** (phi, theta) 그리드를 돌며 `_head_final_point` 결과를 수집.
  - 셀의 네 모서리 중 하나라도 `pit_weight > 0.02`이면 그 셀의 두 삼각형을 방출. 각 정점의 띄움은 실제 패임량으로 캡:

```gdscript
var outset := minf(proud * float(sample["pit_weight"]), float(sample["pit_inset_x"]) * 0.45)
var vertex := (sample["point"] as Vector3) + Vector3(-outset, 0.0, 0.0)
```

    림(가중치 0)에서 셸과 정확히 만나고, 게이프가 작아 패임이 얕을 때도 띄움이 패임의 45%를 넘지 않으므로 원래 표면 밖으로 절대 나가지 않는다.
  - 방출 셀이 하나도 없으면(`mouth_open` 0 등) 빈 ArrayMesh 반환.
  - `st.generate_normals()` 후 commit. UV 불필요(단색 dark 재질).
- [ ] **Step 2: FishRig 교체.** `_add_mouth`(MouthCavity 생성 블록, 현재 `cavity.mesh = _mouth_pit_dark_mesh(...)` 부근):
  - `cavity.mesh = PF.mouth_pit_lining_mesh(shape, snout_length, forehead_slope, rings, segments, _head_sculpt_params())` — 인자는 머리 메쉬를 빌드할 때 쓴 것과 **반드시 동일**해야 한다. `deformed_head_mesh` 호출부를 찾아 같은 변수/기본값(rings/segments 포함)을 사용할 것.
  - **중요:** 새 메쉬는 head-local 좌표이므로 `cavity.position = mouth_position`을 `Vector3.ZERO`로 바꾼다 (기존 메쉬는 `origin` 상대 좌표였음).
  - 재질 설정(`dark_mat.duplicate()` + `CULL_DISABLED`)은 유지.
  - 더 이상 안 쓰는 것 삭제: `_mouth_pit_dark_mesh` 함수 전체, MouthCavity 전용으로 계산하던 `pit_*` 지역 변수들(블록 6c 미러 — `mouth_width_scale`/`buffer_y`/`pit_top`/`pit_bottom`/`pit_half_h`/`pit_center_y`/`pit_half_w`/`pit_depth`가 다른 곳에서 안 쓰이면 함께 정리), 틸트 인자 전달. `_head_mesh_front_x`/`_head_front_surface_x`는 다른 입 메쉬가 아직 쓰므로 남긴다.
- [ ] **Step 3: 테스트.** `-Filter MouthCavityFitTest` 통과 (Task 1의 밀착·비돌출 assert). 기존 `-Filter HeadEditorModelTest`, `-Filter HeadShellSeamTest`, `-Filter MouthShot`이 아닌 스위트 내 머리 관련 테스트 통과.
- [ ] **Step 4: 커밋.** `"Generate mouth cavity lining from the head vertex pipeline"`

### Task 4: MouthFloor 겹침 보정 (테스트 + 육안 확인)

**Files:** `scripts/creature/FishRig.gd`, `scripts/tools/MouthCavityFitTest.gd`, `scripts/tools/MouthShot.gd`

- [ ] **Step 1: 겹침 assert 추가 (실패 확인).** `MouthCavityFitTest.gd`에 z-슬라이스 겹침 검사를 추가한다. `mouth_open` 0.3/0.6/1.0 각각에 대해:
  - `MouthCavity`와 `MouthFloor`의 정점을 같은 head-local 공간으로 변환(각 노드의 `position` 반영; floor 메쉬는 힌지 회전이 메쉬에 구워져 있으므로 추가 회전 불필요).
  - 입 폭을 z-슬라이스 5개(z = `{-0.6, -0.3, 0.0, 0.3, 0.6} × pit_half_w` 근방, 슬라이스 폭 `pit_half_w * 0.2`)로 나누고, 각 슬라이스에서 `max_y(floor 정점) >= min_y(cavity 정점) + buffer_y * 0.5`를 assert — floor 상단/후방 가장자리가 안감 하단 림에 최소 `buffer_y * 0.5`만큼 겹쳐 들어가야 한다. (`buffer_y = 0.03 * lower_jaw_scale * sqrt(mouth_width_scale)` — 테스트에서 동일 식으로 재계산.)
  - 실행해 현재 코드에서 실패(틈 존재)함을 확인. 이미 통과하는 게이프 구간이 있으면 그 구간은 회귀 가드로 유지.
- [ ] **Step 2: 겹침 원칙 적용.** `MouthFloor`(턱과 함께 회전하는 0.82 스케일 `_mouth_lower_jaw_mesh` 사본)와 구덩이 안감 사이 틈을 없앤다. 맞대기 정밀화가 아니라 **겹침**으로 해결: Step 1의 assert가 게이프 전 구간에서 통과하도록 floor 스케일(0.82)·y 오프셋(`+ PF.UPPER_JAW_CARVE_DEPTH * lower_jaw_scale * 0.06`)을 조정한다. 두 메쉬 모두 같은 dark 재질이므로 겹침은 보이지 않고 틈만 보인다.
- [ ] **Step 3: MouthShot 샷 추가.** 기존 3샷(zoom_side, zoom_threeq, zoom_closed)에 Task 1과 같은 공격적 스컬프트 조합의 `zoom_sculpted_side`/`zoom_sculpted_threeq` 2샷 추가. 비-headless로 실행해 `exports/_shots/`에서 확인:
  - 음영이 패임 안에만 있고 실루엣 밖으로 비치지 않는가.
  - 안감 표면에 계단/찢김이 없는가.
  - 안감 하단과 아래턱 음영 사이에 배경색 틈이 없는가 (Step 1과 같은 게이프 변형으로).
- [ ] **Step 4: 테스트 + 커밋.** `-Filter MouthCavityFitTest` 통과 → `"Overlap mouth floor lining with the pit cavity"`

### Task 5: 최종 검증

- [ ] `-Filter MouthCavityFitTest`, `-Filter HeadEditorModelTest`, `-Filter HeadShellSeamTest`, `-Filter JawLinkageTest`, `-Filter HeadDiagnosticTraitTest` 개별 통과.
- [ ] 전체 스위트 `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` 통과 (러너 종료 코드 기준; `Failed to read the root certificate store`는 무시).
- [ ] `git status --short` — 이 계획에 명시된 파일만 변경.

## Out of Scope (후속 후보)

- `_mouth_upper_interior_mesh`·`_mouth_side_aperture_mesh`·`_mouth_band_mesh`의 최근접 정점 클램프 제거 — 이번에 만든 `_head_final_point`/`_head_mesh_precompute`를 재사용해 같은 방식으로 고칠 수 있다.
- 머리 정점 컬러에 구덩이 가중치를 구워 셰이더에서 어둡게 하는 방식(메쉬 자체 제거) — 패턴/마킹 재질 파이프라인과 얽혀 별도 검토 필요.
- cephalofoil(귀상어) 입 음영 — 카브/구덩이가 적용되지 않는 분기로 기존 동작 유지.

## Self-Review

- 음영이 패임과 같은 정점 체인에서 나오므로 "딱 맞음"이 구조적으로 보장됨.
- 띄움을 가중치 비례 + 실제 패임량(`pit_inset_x * 0.45`) 캡으로 이중 제한 → 림에서 셸과 일치하고, 게이프가 작아 패임이 얕은 구간에서도 "밖으로 안 나감"이 성립.
- 아래턱 연결은 정밀 맞대기 대신 겹침 원칙으로 해결해 게이프 변화에 강건함.
- Task 2가 순수 이동임을 기존 기하 테스트로 검증한 뒤에만 신규 동작을 얹는 순서.
