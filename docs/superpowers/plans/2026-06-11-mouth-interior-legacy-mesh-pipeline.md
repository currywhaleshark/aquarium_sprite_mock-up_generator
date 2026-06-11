# 입 내부 레거시 음영 메쉬 파이프라인 이관 계획 (MouthUpperInterior/MouthSideAperture 삭제 + 통합 안감, 윗입술 매몰 수정)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2026-06-10 안감 단일 출처화 이후에도 남은 입 내부 음영 찢어짐을 해결한다. 2026-06-11 격리 렌더(`exports/_shots/isolate/`, `MouthIsolateShot`)로 범인이 확정됐다: ① `MouthUpperInterior` — 스컬프트된 주둥이에서 실루엣 밖까지 뻗는 검은 판, ② `MouthSideAperture` — 입가 실루엣을 뚫는 뾰족한 조각, ③ `MouthLipUpper` — 표면 뒤로 묻혀 찢어진 회색 자국. 셋 다 숨긴 대조군(`legacy_off`)은 두 파라미터 세트 모두 깨끗했고, 새 `MouthCavity` 안감은 문제가 없었다.

**Architecture:** 근본 원인은 세 메쉬가 공유하는 두 가지 결함이다. (1) 최근접 정점 클램프(`_head_mesh_front_x`/`_head_mesh_side_z`)는 (y,z)→x 계단 함수인 데다 `minf`라서 정점을 표면 **앞으로만** 끌어낸다 — 테이퍼된 주둥이에서는 주둥이 끝 정점이 최근접으로 잡혀 메쉬 전체가 실루엣 밖으로 끌려나온다. (2) 메쉬 extents가 mouth_size/origin 기반 해석식이라 실제 카브/구덩이 형상(스컬프트 반영)과 무관하다. 해결은 전 계획과 같은 원칙의 확장이다: **카브(블록 6)의 적용 오프셋도 `_head_final_point` 반환에 노출**하고, 구덩이+카브를 함께 덮는 통합 안감(`mouth_interior_lining_mesh`)을 같은 정점 체인에서 방출해 `MouthCavity`가 쓰게 하며, 역할이 사라진 `MouthUpperInterior`/`MouthSideAperture`는 **삭제**한다. 윗입술은 클램프 **후에** `recess_x`를 더해 묻히는 순서 결함이므로, recess를 클램프의 유효 outset으로 흡수해 표면 앞 최소 이격을 항상 보장한다. 부수 발견인 `MouthFloor` 힌지 불일치(0.82 스케일 사본이 힌지도 0.82로 계산해 본체 턱과 다른 피벗으로 회전)도 소형 태스크로 보정한다.

**Tech Stack:** Godot 4.6.2 GDScript, `tools/run_godot_cli_tests.ps1`, 육안 확인은 `scripts/tools/MouthShot.gd` + 이번 진단에서 만든 `scripts/tools/MouthIsolateShot.gd`(비-headless).

**전제:** `codex/directional-body-head-sculpt-controls` 브랜치, 2026-06-10 안감 계획 5개 커밋(0a82160까지)이 적용된 상태. **Godot 에디터를 닫은 뒤 실행할 것** (에디터가 떠 있으면 headless/CLI 실행 금지 — 프로세스 먼저 확인).

## 사전 조건 (필수 — 작업 시작 전)

- [ ] `Get-Process | Where-Object { $_.ProcessName -match 'godot' }` 로 에디터가 닫혀 있는지 확인.
- [ ] `git status --short` — 현재 `scenes/MouthIsolateShot.tscn`, `scripts/tools/MouthIsolateShot.gd` 두 진단 파일이 untracked로 남아 있다. Task 1에서 함께 커밋하므로 그 외 미커밋 변경이 없는지 확인.

---

## Scope Contract

- `deformed_head_mesh`의 기하 출력은 전후 동일해야 한다. Task 2의 카브 오프셋 노출은 반환 딕셔너리 키 추가일 뿐 정점 좌표를 바꾸지 않는다 (`HeadEditorModelTest`/`HeadShellSeamTest` 기하 assert 그대로 통과).
- 단, `HeadEditorModelTest`의 **입 메쉬 단위 assert는 Task 3에서 갱신된다**: `MouthUpperInterior`/`MouthSideAperture` 존재·extent assert(`HeadEditorModelTest.gd` 384~394행)는 노드 삭제와 함께 통합 안감 커버리지 assert로 교체하고, `_mouth_cavity_head_x_burial`(818행, 한계 0.012)은 (y,z) 최근접 기반이라 카브 림 정점에서 파이지 않은 이웃 정점이 최근접으로 잡혀 값이 커질 수 있으므로 실측 후 재기준선을 잡는다. 머리(Head 메쉬) 기하 assert는 변경 금지.
- 통합 안감의 모든 정점은 같은 (phi, theta) 그리드의 머리 메쉬 정점에서 **적용된 패임(구덩이+카브)의 절반 이내** 거리에 있어야 하고, 패이기 전 원표면 밖으로 절대 나가지 않는다 (비율 50% < 100%).
- **고정 미세 띄움 금지** — 띄움은 반드시 국소 패임량 비례(상한 0.02). 림에서 깊이 버퍼 정밀도 아래로 내려가는 톱니 별 z-fight 회귀(2026-06-11 실측)의 재발 방지. 얕은 셀(아래 임계 미만)은 방출하지 않아 최소 이격을 보장한다: 구덩이 `pit_inset_x >= 0.006`(기존), 카브 `carve_back_x >= 0.012`.
- `mouth_open <= 0.01`이면 안감(`MouthCavity`)이 생성되지 않는 기존 동작 유지. 카브는 영구 형상이지만 닫힌 입에서는 아래턱이 카브를 채우므로 안감도 필요 없다 — FishRig의 `t > 0.01` 게이트가 그대로 이를 보장한다.
- 입 모양 틸트(`_mouth_angle_for_type`)는 안감에 적용하지 않는다 (구덩이/카브 자체가 틸트되지 않음 — 전 계획과 동일).
- 윗입술 recess의 시각적 의도(큰 입에서 입술 띠를 표면 쪽으로 후퇴)는 보존하되, 어떤 mouth_size에서도 정점이 표면 뒤로 묻히지 않아야 한다 (유효 outset 하한 0.012 — 0.004는 비매몰 테스트는 통과하지만 비스듬한 격리 샷에서 깊이/가림 조각이 남았다).
- `MOUTH_DECOR_ENABLED` 분기, 닫힌 입 슬릿(`Mouth` 노드, t<=0.01) 동작 불변.
- 머리/셸 이음새 계약 불변: `HeadShellSeamTest`의 `_max_escape` 한계를 깨지 않는다.
- `_head_front_surface_x`는 `_mouth_position_for_type`과 `_mouth_band_mesh`가 계속 쓰므로 유지. `_head_mesh_side_z`는 side aperture 전용이므로 함께 삭제. `_head_mesh_front_x`는 `_mouth_band_mesh`(슬릿+입술)가 남아 유지.

## File Structure

- Modify `scripts/creature/PrimitiveFactory.gd`: `_head_final_point` 반환에 카브 오프셋 추가, `mouth_pit_lining_mesh` → `mouth_interior_lining_mesh` 확장(구덩이+카브 셀 방출, 패임 벡터 비례 띄움).
- Modify `scripts/creature/FishRig.gd`: `MouthCavity`가 통합 안감 사용, `MouthUpperInterior`/`MouthSideAperture` 생성 블록 + `_mouth_upper_interior_mesh`/`_mouth_side_aperture_mesh`/`_head_mesh_side_z` 삭제, `_mouth_band_mesh` recess 흡수, `_mouth_lower_jaw_mesh` 힌지 스케일 분리.
- Add `scripts/tools/MouthInteriorContainmentTest.gd` + `scenes/MouthInteriorContainmentTest.tscn`: 어두운 내부 메쉬 비돌출 회귀 테스트(Task 3 green).
- Add `scripts/tools/MouthLipBurialTest.gd` + `scenes/MouthLipBurialTest.tscn`: 윗입술 비매몰 회귀 테스트(Task 4 green).
- Modify `scripts/tools/HeadEditorModelTest.gd`: 삭제 노드 존재·extent assert(384~394행)를 통합 안감 커버리지로 교체, `_mouth_cavity_head_x_burial` 한계 재기준선(필요시).
- Commit + Modify `scripts/tools/MouthIsolateShot.gd` + `scenes/MouthIsolateShot.tscn`: 노드별 격리 샷 도구(스위트 제외, 이미 작업 트리에 존재; Task 3에서 삭제 노드 변형 제거).

---

### Task 1: 진단 도구 커밋 + 회귀 테스트 작성 (현재 코드로 실패 입증)

**Files:** `scripts/tools/MouthIsolateShot.gd`(기존), `scenes/MouthIsolateShot.tscn`(기존), `scripts/tools/MouthInteriorContainmentTest.gd`, `scenes/MouthInteriorContainmentTest.tscn`, `scripts/tools/MouthLipBurialTest.gd`, `scenes/MouthLipBurialTest.tscn`

- [ ] **Step 1: 진단 도구 커밋.** 작업 트리에 있는 `MouthIsolateShot` 2파일(+ 실행 시 생긴 `.uid`)을 그대로 커밋: `git commit -m "Add mouth node isolation shot tool"`. (배경색·줌은 진단 당시 값 유지 — 육안 비교 기준선.)
- [ ] **Step 2: 테스트 작성.** 두 테스트 모두 같은 두 파라미터 세트로 FishRig를 빌드한다. 격리 렌더에서 깨짐을 재현한 조합 그대로:

```gdscript
var pale := {
	"shell_enabled": 1.0, "mouth_type": "terminal",
	"mouth_open": 1.0, "mouth_size": 0.2,
}
var sculpted := {
	"shell_enabled": 1.0, "mouth_type": "terminal",
	"head_shape": "rounded", "snout_length": 0.45, "snout_taper": 0.7,
	"snout_thickness": 0.6, "head_belly_curve": -0.7,
	"head_bottom_flatness": 0.8, "head_bump_height": 0.3,
	"mouth_open": 1.0, "mouth_size": 0.14,
}
```

  하니스 관례·헬퍼는 `scripts/tools/MouthCavityFitTest.gd`를 그대로 따른다 — `_fail`(push_error + quit(1), 7행), `_mesh_vertices_in_parent_space`(노드 `transform` 적용으로 head-local 변환, 12행), `_nearest_vertex`(**3D** 최근접, 20행)를 복사해 쓴다.
  - **`MouthInteriorContainmentTest.gd` (Task 3 green):** 각 세트 × `mouth_open` {0.3, 1.0}에 대해 검사한다. 검사 대상은 어두운 내부 메쉬만 **명시 목록**으로 한정한다: `const INTERIOR_DARK_NODES := ["MouthCavity", "MouthUpperInterior", "MouthSideAperture"]` — `get_node_or_null`로 존재하는 것만 검사(Task 3 이후 뒤 둘은 사라지고 통합 안감이 계속 가드를 받는다). `MouthLowerJaw`/`MouthFloor`/`MouthLipUpper`는 **검사하지 않는다** — 턱/floor는 게이프 시 머리 표면 밖으로 스윙하는 것이 정상이다. 각 노드의 모든 정점 v에 대해: `nearest = _nearest_vertex(v, head_verts)`(3D 최근접), `nearest.x - v.x < 0.022` (MouthCavityFitTest의 `worst_ahead` 한계와 동일 — 정상 안감의 띄움 상한 0.02를 통과시키되 실루엣 탈출은 잡는다). — 현재 `MouthUpperInterior`(sculpted에서 크게)와 `MouthSideAperture`(pale에서)가 실패해야 한다. 만약 통과하면 격리 렌더와 같은 조합이므로 파라미터를 더 키워 재현 후 진행. 닫힌 입 확인: `mouth_open: 0.0`으로 재설정하면 `INTERIOR_DARK_NODES` 셋 다 없다 (`get_node_or_null` null 확인).
  - **`MouthLipBurialTest.gd` (Task 4 green):** 각 세트 × `mouth_open` {0.3, 1.0}에 대해 `MouthLipUpper`의 모든 정점 검사: `v.x - nearest.x < 0.002` (표면 뒤로 0.002 이상 묻힘 금지). — 현재 recess 매몰로 실패해야 한다 (mouth_size 0.2: 매몰 ≈ 0.0216, 0.14: ≈ 0.0084).
  - 통과 시 `print("MOUTH_INTERIOR_FIT_TEST_OK")` + `exports/test_results/mouth_interior_fit.ok` 기록 후 `quit(0)` (기존 관례).

  `MouthInteriorContainmentTest.gd` 스크립트 골격 (세부는 MouthCavityFitTest 참고):

```gdscript
extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

const INTERIOR_DARK_NODES := ["MouthCavity", "MouthUpperInterior", "MouthSideAperture"]
const MAX_AHEAD := 0.022       # = MouthCavityFitTest worst_ahead 한계
const MAX_LIP_BURIAL := 0.002

func _fail(message: String) -> bool: ...                         # MouthCavityFitTest.gd:7 복사
func _mesh_vertices_in_parent_space(node: MeshInstance3D) ...    # 동 12행 복사
func _nearest_vertex(point: Vector3, candidates: ...) ...        # 동 20행 복사

func _assert_interior_contained(fish: FishRig, label: String) -> bool:
	# head_verts = Head 메쉬 정점, INTERIOR_DARK_NODES 중 존재하는 노드의
	# 정점 전부에 대해 nearest.x - v.x < MAX_AHEAD, 위반 시 _fail(label/노드/값)

func _assert_lip_not_buried(fish: FishRig, label: String) -> bool:
	# MouthLipUpper 정점 전부 v.x - nearest.x < MAX_LIP_BURIAL

func _ready() -> void:
	# fish 생성(auto_animate=false, add_child) 후
	# {pale, sculpted} × mouth_open {0.3, 1.0}: set_parameters → await process_frame
	#   → _assert_interior_contained (실패 시 return)
	# mouth_open 0.0: INTERIOR_DARK_NODES 부재 확인
	# ok 파일 기록 + print("MOUTH_INTERIOR_CONTAINMENT_TEST_OK") + quit(0)
```

  `MouthLipBurialTest.gd`는 같은 헬퍼와 파라미터 세트를 쓰되 `_assert_lip_not_buried`만 실행한다. ok 파일은 `exports/test_results/mouth_lip_burial.ok`, 성공 출력은 `MOUTH_LIP_BURIAL_TEST_OK`.

  `MouthInteriorContainmentTest.tscn` (러너는 `scenes/*Test.tscn`만 발견하므로 필수):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tools/MouthInteriorContainmentTest.gd" id="1"]

[node name="MouthInteriorContainmentTest" type="Node"]
script = ExtResource("1")
```

  `MouthLipBurialTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tools/MouthLipBurialTest.gd" id="1"]

[node name="MouthLipBurialTest" type="Node"]
script = ExtResource("1")
```
- [ ] **Step 3: 실패 확인.**
  - `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MouthInteriorContainmentTest` — 비돌출 assert에서 실패해야 한다.
  - `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MouthLipBurialTest` — 비매몰 assert에서 실패해야 한다.
- [ ] **Step 4: 커밋.** 테스트 + tscn + `.uid` 사이드카(프로젝트는 uid를 추적한다 — f62b3f3 참조) → `"Add failing mouth interior containment regression test"`

### Task 2: `_head_final_point`에 카브 오프셋 노출 (순수 추가)

**Files:** `scripts/creature/PrimitiveFactory.gd`

- [ ] **Step 1: 반환 확장.** 블록 6(영구 카브)에서 적용한 증분을 지역 변수로 잡아 반환 딕셔너리에 추가한다 — `"carve_back_x"`(= `UPPER_JAW_CARVE_BACK * lower_jaw_scale * upper_carve_size_scale * carve_w`), `"carve_up_y"`(= `UPPER_JAW_CARVE_UP * ... * carve_w`). 카브 분기를 타지 않으면 0.0. **정점 좌표 계산은 일절 바꾸지 않는다.**
- [ ] **Step 2: 회귀 확인.**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeamTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MouthCavityFitTest
```

- [ ] **Step 3: 커밋.** `"Expose upper-jaw carve offsets from the head vertex pipeline"`

### Task 3: 통합 입 내부 안감 + 레거시 메쉬 2종 삭제

**Files:** `scripts/creature/PrimitiveFactory.gd`, `scripts/creature/FishRig.gd`

- [ ] **Step 1: 안감 생성기 확장.** `mouth_pit_lining_mesh`를 `mouth_interior_lining_mesh`로 개명·확장 (호출부가 FishRig 한 곳뿐이므로 개명 안전):
  - 셀 방출 조건: 네 모서리 모두 `pit_inset_x >= MOUTH_LINING_MIN_INSET`(0.006) **또는** 네 모서리 모두 `carve_back_x >= MOUTH_LINING_MIN_CARVE`(신규 상수 0.012). 두 조건을 따로 검사해 합집합 셀을 방출한다 (구덩이와 카브가 겹치는 셀은 한 번만).
  - 정점 띄움: 적용된 패임 벡터의 절반을 되돌린다 — `var back := Vector3(-(float(s["pit_inset_x"]) + float(s["carve_back_x"])) * 0.5, -float(s["carve_up_y"]) * 0.5, 0.0)`; `back.length() > proud`(0.02)이면 `back = back.normalized() * proud`. 비율 50% < 100%이므로 어떤 조합에서도 패이기 전 원표면 밖으로 나가지 않고, 방출 임계 덕에 최소 이격(≥0.003 상당)이 보장돼 z-fight하지 않는다.
  - 같은 dark 재질의 셀들이 한 메쉬로 나오므로 구덩이/카브 경계는 보이지 않는다.
- [ ] **Step 2: FishRig 정리.** `_add_mouth`에서:
  - `cavity.mesh = PF.mouth_interior_lining_mesh(...)` — 인자/rings/segments(18, 24)는 머리 메쉬 빌드와 동일 유지.
  - `MouthUpperInterior`·`MouthSideAperture` 생성 블록 삭제. `_mouth_upper_interior_mesh`, `_mouth_side_aperture_mesh`, `_head_mesh_side_z` 함수 삭제. `head_verts`는 `_mouth_band_mesh`(슬릿+입술)가 아직 쓰므로 유지.
- [ ] **Step 3: HeadEditorModelTest 갱신.** 삭제된 노드를 전제하는 assert를 통합 안감 기준으로 교체한다 (`scripts/tools/HeadEditorModelTest.gd`):
  - 384~394행의 `MouthUpperInterior`/`MouthSideAperture` 존재·extent assert 블록을 제거하고, 그 자리에서 같은 의도(열린 입의 어두운 천장/측면 커버리지)를 통합 안감으로 검증한다: `MouthCavity`의 `_mesh_extent` x/y가 구덩이 전용 안감 대비 커브 영역까지 커졌는지 — 구현 후 실측값에 여유를 둔 하한으로 잡고, 기준 근거를 주석으로 남긴다.
  - 381행 `_mouth_cavity_visible_x_extent > 0.16`, 380행 z-leak ≤ 0.015는 그대로 둔다(안감이 커져도 위반 방향이 아님).
  - 383행 `_mouth_cavity_head_x_burial(fish) <= 0.012`는 (y,z) 최근접 기반이라 카브 림 정점의 최근접이 파이지 않은 이웃 정점으로 잡히면 값이 커질 수 있다. 실측해 통과하면 그대로 두고, 초과하면 한계를 실측+여유로 재기준선하되 "카브 림의 (y,z) 최근접 미스매치" 사유를 주석으로 남긴다. **이 한계 완화 외에 헬퍼 로직 자체는 바꾸지 않는다.**
- [ ] **Step 4: MouthIsolateShot 갱신.** `MOUTH_NODES`에서 삭제된 두 노드를 빼고 `["MouthCavity", "MouthFloor", "MouthLowerJaw", "MouthLipUpper"]`로, `legacy_off` 변형은 `["MouthLipUpper"]`만 숨기는 `lip_off`로 교체 — 삭제된 노드가 `MISSING_NODE` 출력과 중복 샷을 만들지 않게 한다.
- [ ] **Step 5: 테스트 + 육안.**
  - `-Filter MouthInteriorContainmentTest` — 통과(레거시 삭제 + 안감 자체가 계약상 표면 안쪽).
  - `-Filter MouthLipBurialTest` — 아직 실패해야 한다(Task 4에서 해결).
  - `-Filter MouthCavityFitTest`, `-Filter HeadEditorModelTest`(Step 3 갱신 반영), `-Filter HeadShellSeamTest`, `-Filter JawLinkageTest` 통과.
  - 비-headless로 `scenes/MouthIsolateShot.tscn` 실행 → `exports/_shots/isolate/`에서: 실루엣 밖 검은 판/가시 소멸, **게이프 0.3/0.6/1.0에서 입 내부(특히 카브 천장)가 빠짐없이 어둡고 몸색이 비치지 않는지**, 림에 톱니 z-fight가 없는지. 천장 커버가 부족하면 `MOUTH_LINING_MIN_CARVE`를 낮추되 z-fight 재발 여부를 같은 샷으로 재확인.
- [ ] **Step 6: 커밋.** `"Replace legacy mouth interior meshes with the unified pipeline lining"`

### Task 4: 윗입술 매몰 수정 (recess를 클램프로 흡수)

**Files:** `scripts/creature/FishRig.gd`

- [ ] **Step 1: `_mouth_band_mesh` 수정.** 클램프 후 `p.x += recess_x`를 더하는 대신, recess를 클램프의 유효 outset으로 흡수한다: `clamp_surface`일 때 `p.x = _head_mesh_front_x(head_verts, p.y, p.z, maxf(outset - recess_x, 0.012))`, 별도의 `p.x += recess_x` 라인은 비클램프 경로에서만 적용(현재 비클램프 호출부는 recess 0이므로 사실상 제거). 시각 효과는 동일 방향(입술이 표면 쪽으로 후퇴)이되 하한 0.012로 절대 묻히지 않고 비스듬한 샷에서 깊이 조각이 남지 않게 한다.
- [ ] **Step 2: 테스트 + 육안.** `-Filter MouthInteriorContainmentTest`와 `-Filter MouthLipBurialTest` 모두 통과. `MouthIsolateShot` 재실행 — 주둥이 위 회색 찢김 자국이 사라지고 입술 띠가 연속인지. 닫힌 입(`zoom_closed`, MouthShot)에서 슬릿/입술이 기존과 동일한지.
- [ ] **Step 3: 커밋.** `"Keep the upper lip band proud of the head surface"`

### Task 5: MouthFloor 힌지 피벗 일치 (소형)

**Files:** `scripts/creature/FishRig.gd`

- [ ] **Step 1: 힌지 스케일 분리.** `_mouth_lower_jaw_mesh`에 `hinge_scale: float = -1.0` 인자를 추가하고(음수면 `jaw_scale` 사용 — 기존 호출 동작 불변), 힌지 계산(`_lower_jaw_hinge_local(origin, hinge_scale, ...)`)에만 이를 쓴다. `MouthFloor` 호출부는 `jaw_scale = lower_jaw_scale * 0.82, hinge_scale = lower_jaw_scale`로 바꿔 본체 턱과 **같은 피벗**으로 회전하게 한다. `MouthLowerJaw` 호출부는 변경 없음.
- [ ] **Step 2: 회귀 확인.** `-Filter MouthCavityFitTest`(floor 겹침 assert 포함), `-Filter JawLinkageTest`, `-Filter MouthInteriorContainmentTest`, `-Filter MouthLipBurialTest` 통과. `MouthIsolateShot`에서 게이프 1.0일 때 floor와 안감 사이 배경색 틈이 없는지 육안 확인. 겹침 assert가 깨지면 floor의 y 리프트 계수(`0.06 + 0.38 * t`)를 재조정.
- [ ] **Step 3: 커밋.** `"Rotate the mouth floor about the real jaw hinge"`

### Task 6: 최종 검증

- [ ] `-Filter MouthInteriorContainmentTest`, `-Filter MouthLipBurialTest`, `-Filter MouthCavityFitTest`, `-Filter HeadEditorModelTest`, `-Filter HeadShellSeamTest`, `-Filter JawLinkageTest`, `-Filter HeadDiagnosticTraitTest` 개별 통과.
- [ ] 전체 스위트 `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` 통과 (`Failed to read the root certificate store`는 무시).
- [ ] 비-headless `MouthShot` + `MouthIsolateShot` 실행, 셔터 샷 전체 육안: 음영이 입 내부에만, 실루엣 밖 무돌출, 찢김/계단/톱니 없음, floor-안감 무틈.
- [ ] `git status --short` — 이 계획에 명시된 파일만 변경.

---

## 2차 후속: 통합 안감 1차 구현(커밋 aa8c532~3c74fd9)의 시각 회귀 (2026-06-11 격리 렌더 재진단)

Task 1~6 구현 후 세 가지 시각 회귀가 관찰·재현됐다 (`exports/_shots/isolate/`의 게이프 스윕 + 옆모습 격리 샷, `MouthIsolateShot` 확장판):

- **(A) 림 톱니/가시:** 안감이 18×24 그리드 셀을 통째로 방출/스킵해서, 카브 falloff의 임계 등고선(0.012)이 보이는 볼록면 위를 지나는 곳에서 림이 셀 단위 삼각 이빨로 양자화된다. 열린 입의 뾰족 돌출(`pale_full`)과 옆모습의 지그재그 띠가 같은 원인이다 — 옆모습 격리에서 `side_no_MouthFloor`는 무변화, `side_no_MouthCavity`에서 띠가 소멸했으므로 **"아래턱 음영 두께"로 보였던 것의 주범도 MouthFloor가 아니라 안감 림 띠**다 (pale/sculpt 두 세트 모두).
- **(B) 게이프 무응답:** 블록 6 카브는 영구 형상이라 `carve_back_x`에 게이프 항이 없고, 방출 임계가 상수라서 `mouth_open` 0.02~1.0 전 구간에서 카브 천장 음영이 풀사이즈다 (`full_g005`에서도 검은 띠 선명, `full_g030` ≈ `full_g100`). 레거시 `_mouth_upper_interior_mesh`는 높이가 `lerpf(0.34, 0.76, g)`로 게이프에 비례했었다. t=0.01 게이트에서 풀사이즈→소멸 불연속도 있다.
- 봉쇄 테스트(`MouthInteriorContainmentTest`)가 못 잡은 이유: 세 증상 모두 원표면 안쪽에서 일어나는 **커버리지 형상/게이프 응답** 문제라 봉쇄 계약을 위반하지 않는다.

### Task 7: 진단 도구 확장판 + 사이드카 커밋

**Files:** `scripts/tools/MouthIsolateShot.gd`(작업 트리에 수정본 존재), 미추적 `.uid` 3개

- [ ] **Step 1:** 작업 트리의 `MouthIsolateShot.gd` 확장(게이프 스윕 `full_g005/g030`, 옆모습 `side_g030/g100`, `side_no_MouthFloor`/`side_no_MouthCavity` 격리)과 미추적 `.uid` 사이드카(`MouthInteriorContainmentTest.gd.uid`, `MouthIsolateShot.gd.uid`, `MouthLipBurialTest.gd.uid`)를 커밋: `"Extend mouth isolation shots with gape sweep and side views"`

### Task 8: 카브 커버리지 게이프 게이팅 (회귀 B)

**Files:** `scripts/creature/PrimitiveFactory.gd`, `scripts/tools/MouthInteriorContainmentTest.gd`

- [ ] **Step 1: 게이프 응답 테스트 추가 (실패 입증).** `MouthInteriorContainmentTest`에 추가: pale 세트에서 `MouthCavity` 메쉬의 y-extent(head-local)를 게이프 0.05/0.3/1.0에서 측정해 `extent_y(0.05) < 0.35 × extent_y(1.0)` 그리고 `extent_y(0.3) < 0.9 × extent_y(1.0)` assert (수치는 구현 전 실측으로 보정하되 "근사 닫힘에서 띠가 사라질 것"이라는 의도 유지). 현재 코드로 실패 확인.
- [ ] **Step 2: 방출 게이팅.** `mouth_interior_lining_mesh`에서 카브 셀 판정에만 게이프를 반영한다 — `precomputed["jaw_gape"]`(이미 존재, `sculpt["mouth_open"]` 유래)로 `var reveal := smoothstep(0.0, MOUTH_LINING_REVEAL_GAPE, jaw_gape)` (신규 상수, 실측 튜닝값 1.0), 판정을 `min_carve_back * reveal >= MOUTH_LINING_MIN_CARVE`로. **띄움 계산(`_mouth_lining_vertex`)은 실제 패임 그대로 둔다** — 방출된 셀의 실제 카브가 `0.012 / reveal ≥ 0.012`이므로 최소 이격 0.006이 오히려 강화되고 봉쇄·z-fight 계약 불변. 구덩이(`pit_inset_x`)는 자체적으로 게이프 비례라 게이팅하지 않는다.
- [ ] **Step 3: 검증.** Step 1 테스트 통과, `-Filter MouthCavityFitTest`/`-Filter HeadEditorModelTest` 통과(통합 안감 extent assert가 게이프 1.0 기준이면 영향 없음 — 깨지면 해당 assert의 게이프를 1.0으로 고정), `MouthIsolateShot`에서 `full_g005`에 검은 띠가 사실상 안 보이고 g030→g100으로 자연스럽게 커지는지 육안. `MOUTH_LINING_REVEAL_GAPE`가 유일한 튜닝 노브.
- [ ] **Step 4: 커밋.** `"Reveal the carve lining proportionally to the gape"`

### Task 9: 림 등고선 보간 (회귀 A — 뾰족 가시 + 옆모습 톱니)

**Files:** `scripts/creature/PrimitiveFactory.gd`

- [x] **Step 1: marching-squares 부분 셀 방출.** 셀 통째 방출/스킵 대신, 모서리별 스칼라 필드 `field := maxf(pit_inset_x / MOUTH_LINING_MIN_INSET, carve_eff / MOUTH_LINING_MIN_CARVE) - 1.0`(`carve_eff = carve_back_x * reveal`, Task 8)로 등고선 `field = 0`을 셀 변 위에서 선형 보간해 부분 폴리곤(3~6각)을 팬 삼각분할로 방출한다. 보간 정점의 샘플 값(point, pit_inset_x, carve_back_x, carve_up_y)도 같은 비율로 lerp한 뒤 `_mouth_lining_vertex`에 넣는다 — 등고선 위 정점의 패임이 정확히 임계값이므로 띄움이 0.003~0.006으로 보장돼 z-fight 계약 유지. 4모서리 전부 통과/전부 미달 셀은 기존과 동일 동작(전량 방출/스킵). `MOUTH_LINING_REVEAL_GAPE`는 부분 셀의 얇은 극단부까지 gape extent에 잡히므로 1.5로 재튜닝했다.
- [x] **Step 2: 검증.** `-Filter MouthInteriorContainmentTest`(보간 정점도 두 안쪽 점의 lerp이므로 봉쇄 유지 — 통과해야 정상), `-Filter MouthCavityFitTest`, `-Filter HeadEditorModelTest`. 보간 정점은 head 정점 격자 사이에 생기므로 `MouthInteriorContainmentTest`/`MouthCavityFitTest`/`HeadEditorModelTest`의 관련 검사는 최근접 정점 대신 head 삼각면 최근접 기준으로 보강했다. `MouthIsolateShot` 육안: 열린 입 림의 삼각 이빨 소멸, 옆모습(`side_g100`) 턱선의 지그재그 띠가 매끈한 곡선 띠로.
- [x] **Step 3: 커밋.** `"Interpolate the mouth lining rim to the emission isoline"`

### Task 10: 최종 검증 + 조건부 MouthFloor 박형화

- [ ] 전체 스위트 + `MouthShot`/`MouthIsolateShot` 육안 (Task 6 체크리스트 재실행).
- [ ] **조건부:** Task 8~9 후에도 사용자 조합에서 "아래턱 음영 두께"가 남으면 그때만 `MouthFloor` 돔을 박형화(깊이 ×0.3 별도 인자) + 리프트 `(0.06 + 0.38t)` 재조정. 격리 렌더에서는 floor가 옆모습에 기여하지 않았으므로(증거: `side_no_MouthFloor` 무변화) 선제 작업하지 않는다.

## Out of Scope (후속 후보)

- 입형 틸트(superior/inferior/subterminal)와 구덩이/안감의 정합 — 구덩이 자체가 틸트되지 않는 기존 동작 유지. 틸트 입형에서 안감이 어긋나 보이면 블록 6c에 틸트를 넣는 별도 작업.
- `_mouth_band_mesh`의 최근접 정점 계단 자체(매몰만 고치고 계단은 유지) — 거슬리면 (y,z) 역거리 가중 4-정점 블렌드로 후속.
- cephalofoil 입 음영 — 카브/구덩이 미적용 분기 기존 동작 유지.
- `MouthLowerJaw`/`MouthFloor`의 해석적 돔 형상 자체의 파이프라인 이관.

## Self-Review

- 격리 렌더로 범인이 노드 단위로 입증된 상태에서, 각 범인에 대해 "삭제 가능(통합 안감이 대체)" 또는 "순서 결함 수정"이라는 최소 변경을 택했다.
- 통합 안감은 전 계획에서 검증된 원칙(같은 정점 체인, 패임 비례 50% 띄움, 얕은 셀 스킵)의 확장이라 새로운 근사를 도입하지 않는다.
- Task 1의 비돌출 가드는 어두운 내부 메쉬 명시 목록(`INTERIOR_DARK_NODES`)에만 건다 — 턱/floor는 게이프 시 표면 밖 스윙이 정상이라 포함하면 거짓 양성이 난다. Task 3 이후에는 목록 중 통합 안감만 남아 같은 가드를 계속 받는다. 임계(0.022)는 기존 `MouthCavityFitTest`의 `worst_ahead` 한계와 통일해 정상 안감(띄움 ≤ 0.02)을 통과시킨다.
- 카브 천장 커버리지(MOUTH_LINING_MIN_CARVE 임계)는 유일한 튜닝 포인트로, Task 3 Step 3의 육안 게이트에서 z-fight와 트레이드오프를 같은 샷 도구로 확인한다.
