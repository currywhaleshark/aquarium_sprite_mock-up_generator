# 2단계: 프리뷰 직접 조작 확장 구현 계획 (링 핸들 드래그 · 턱/혹 핸들 · Pick-to-Edit)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 슬라이더로만 가능하던 핵심 조작을 프리뷰에서 직접 드래그로 수행한다. ① 바디 링 가이드의 상/하/중심점 드래그로 `upper_height`/`lower_height`/`x`/`y_offset` 편집, ② 턱 관절(jaw hinge)·머리 혹(bump) 드래그 핸들, ③ 프리뷰에서 부위 클릭 시 해당 패널 섹션 자동 펼침+스크롤(Pick-to-Edit).

**Architecture:** 기존 직접 조작 인프라를 확장하되, 드래그 커밋 규약(픽킹 → 라이브 드래그는 emit 없이 → 릴리즈 시 1회 `parameters_changed` emit, 카메라 드래그 억제)만 공유하고 좌표 변환은 새 `ScreenDragProjector` 헬퍼로 분리한다. 바디 링은 이미 존재하는 3D 링 가이드(`FishRig._add_ring_guides`)와 클릭 선택(`Main._on_preview_gui_input`)을 드래그 가능한 핸들로 승격한다. 화면 좌표→월드 델타는 카메라 ray와 핸들별 편집 평면의 교차점 차이로 계산해 카메라 회전/줌 상태에서도 화면상 방향감각을 보존하고, 월드 델타→파라미터 델타 변환은 FishRig 안의 메서드(`drag_ring_handle`, `move_jaw_hinge`, `move_head_bump`)가 담당한다.

**Tech Stack:** Godot 4 GDScript, `tools/run_godot_cli_tests.ps1`, `scripts/ui` + `scripts/creature`.

**전제:** 1단계 계획(슬라이더 탐색성)과 독립적으로 구현 가능. 단, 1단계의 `DragHandlesOverlay.indicator_key` 변경이 먼저 머지됐다면 `show_jaw_hinge` 참조가 이미 제거된 상태이므로 충돌에 주의.

---

## Scope Contract

- 드래그 커밋 규약: 마우스 이동 중에는 rig만 갱신하고 `parameters_changed`를 emit하지 않는다. 릴리즈 시 1회 emit. (기존 `FishFinDragController` 및 `EditorDragEmissionTest`와 동일 규약.)
- 드래그로 만든 값은 패널 슬라이더와 동일한 clamp 범위를 따른다. 링 키 범위의 단일 출처를 `BodyProfile.gd`의 상수로 옮기고 `BodyEditorPanel.RING_NUMERIC_KEYS`가 이를 참조하게 한다 (UI→creature 역방향 의존 금지).
- 링 핸들 드래그는 해당 링의 대상 필드만 변경한다. top 드래그는 `upper_height`만, bottom은 `lower_height`만, center는 `x`/`y_offset`만.
- 라이브 드래그 중 rig 재구축은 프레임당 최대 1회로 스로틀한다 (델타 누적 → `_process`에서 적용).
- 카메라 회전/줌 상태에서도 드래그 방향감각을 보장한다. 고정 `DRAG_WORLD_PER_PIXEL` 상수로 새 직접 조작을 구현하지 말고, `Camera3D.project_ray_origin/project_ray_normal` ray를 핸들 편집 평면과 교차시켜 이전/현재 마우스 위치의 월드 차이를 사용한다.
- 편집 모드 배타성 유지: 링 핸들은 바디 편집 모드에서만, 턱/혹 핸들은 머리 편집 모드에서만 픽킹·표시된다. 바디 편집 모드에서는 `FishFinDragController` 입력을 비활성화하고 `BodyRingDragController`만 preview 입력을 소유한다. `EditModeExclusivityTest`가 깨지면 안 된다.
- Pick-to-Edit은 포커스(섹션 펼침+스크롤)만 수행하고 파라미터를 변경하지 않는다.
- 레거시 프리셋·기존 테스트 동작 불변. 핸들이 없는 상태(예: ray, 턱 없음)에서는 해당 핸들이 조용히 생략된다.

## File Structure

- Modify `scripts/creature/BodyProfile.gd`: 링 키 clamp 범위 상수 `RING_KEY_RANGES` 신설.
- Modify `scripts/ui/BodyEditorPanel.gd`: `RING_NUMERIC_KEYS`가 `BodyProfile.RING_KEY_RANGES` 참조.
- Modify `scripts/creature/FishRig.gd`: `get_body_ring_handles()`, `get_body_ring_drag_plane()`, `drag_ring_handle()`, `get_head_drag_plane()`, `move_jaw_hinge()`, `move_head_bump()`, `get_head_bump_world()`(기존 `_head_bump_indicator_world()` 공개/재사용), `get_drag_handles()` 확장.
- Add `scripts/ui/ScreenDragProjector.gd`: 카메라 ray와 편집 평면 교차로 화면 드래그를 월드 델타로 변환.
- Add `scripts/ui/BodyRingDragController.gd`: 바디 링 핸들 픽킹/드래그 컨트롤러.
- Modify `scripts/ui/FishFinDragController.gd`: `jaw_hinge`/`head_bump` 분기, 모드별 핸들 필터, `handle_clicked` 시그널.
- Modify `scripts/ui/DragHandlesOverlay.gd`: 신규 핸들 표시(`_should_draw_handle` 확장), 링 핸들 호버 표시.
- Modify `scripts/ui/HeadEditorPanel.gd`: `focus_key(key) -> Control` (섹션 펼침 + 행 반환).
- Modify `scripts/ui/FinEditorPanel.gd`: `select_slot(slot_id)` 공개 메서드.
- Modify `scripts/ui/Main.gd`: BodyRingDragController 와이어링, 기존 클릭-선택 코드 이관, Pick-to-Edit 라우팅(`editor_panel_scroll.ensure_control_visible`).
- Add `scripts/tools/BodyRingDragTest.gd` + `scenes/BodyRingDragTest.tscn`.
- Add `scripts/tools/ScreenDragProjectorTest.gd` + `scenes/ScreenDragProjectorTest.tscn`.
- Add `scripts/tools/HeadHandleDragTest.gd` + `scenes/HeadHandleDragTest.tscn`.
- Add `scripts/tools/PickToEditTest.gd` + `scenes/PickToEditTest.tscn`.
- Modify `scripts/tools/DragHandlesTest.gd`, `scripts/tools/EditorDragEmissionTest.gd`: 신규 핸들/컨트롤러 커버.

---

### Task 1: 링 키 범위 단일 출처화

**Files:** `scripts/creature/BodyProfile.gd`, `scripts/ui/BodyEditorPanel.gd`

- [ ] **Step 1:** `BodyProfile.gd`에 `const RING_KEY_RANGES := {...}` 추가 — 현재 `BodyEditorPanel.RING_NUMERIC_KEYS`의 min/max/step을 그대로 이동.
- [ ] **Step 2:** `BodyEditorPanel.RING_NUMERIC_KEYS`를 `const RING_NUMERIC_KEYS := BodyProfileScript.RING_KEY_RANGES` 직접 참조로 교체한다. 이후 `BodyEditorPanel.gd` 안의 모든 `RING_NUMERIC_KEYS` 사용은 그대로 유지해 테스트·패널 코드의 공개 표면을 바꾸지 않는다.
- [ ] **Step 3:** `-Filter BodyEditorPanelTest` 통과 확인 → 커밋 `"Single-source body ring key ranges"`

### Task 2: FishRig 링 핸들 API

**Files:** `scripts/creature/FishRig.gd`, `scripts/tools/BodyRingDragTest.gd` + tscn

- [ ] **Step 1: 실패하는 테스트.** `BodyRingDragTest.gd`: 기본 fish + `set_ring_editor_enabled(true)` 상태에서
  - `get_body_ring_handles()`가 링별 `{"center": Vector3, "top": Vector3, "bottom": Vector3}` 반환, 좌표가 `_add_ring_guides`가 배치하는 가이드 구체 위치와 일치.
  - `drag_ring_handle("mid_body", "top", Vector3(0, 0.1, 0))` 후 해당 링의 `upper_height`만 증가(다른 링·다른 키 불변), 월드 top 점이 위로 이동.
  - `"bottom"` 드래그(아래 방향)는 `lower_height`만 증가.
  - `"center"` 드래그는 `x`(가로)와 `y_offset`(세로)만 변경, `x`는 이웃 링 사이로 clamp되고 링 순서가 유지됨.
  - 범위 초과 드래그가 `RING_KEY_RANGES`로 clamp됨.
- [ ] **Step 2: 구현.**
  - `get_body_ring_handles()`: `_add_ring_guides`의 좌표 계산(`shell_profile[i]`, `shell_center_y_offsets[i]`, z = `-point.z - 0.03`)을 헬퍼로 추출해 가이드 생성과 핸들 좌표가 같은 코드를 쓰게 한다. `body_pivot.to_global` 적용.
  - `get_body_ring_drag_plane(ring_id: String, part: String) -> Dictionary`: 해당 핸들 월드 위치를 `point`, `body_pivot.global_transform.basis.z.normalized()`를 `normal`로 반환한다. 이 평면은 body side-profile x/y 편집 평면이며 카메라 회전/줌 변환의 기준이다.
  - `drag_ring_handle(ring_id: String, part: String, world_delta: Vector3) -> void`: 카메라 보정이 끝난 월드 델타를 `body_pivot.global_basis.inverse()`로 body local 델타로 바꾼 뒤 파라미터 단위로 변환한다. 세로는 `body_height`로, 가로는 shell x 범위(`start_x..end_x`, `_build_shell_profile_from_rings` 참조)로 정규화. `parameters["body_profile"]["rings"]`를 직접 변형 후 `rebuild()`. clamp는 `BodyProfile.RING_KEY_RANGES`.
  - 주의: `rebuild()`가 가이드도 다시 만들므로 드래그 중 핸들 좌표 재조회 필요 — 컨트롤러가 매 프레임 `get_body_ring_handles()`를 다시 읽는 구조로 설계.
- [ ] **Step 3:** `-Filter BodyRingDragTest` 통과, `-Filter RingHeightDecoupleTest`·`-Filter ShellRigTest` 회귀 통과 → 커밋 `"Add draggable body ring handle API"`

### Task 3: BodyRingDragController + Main 와이어링

**Files:** `scripts/ui/ScreenDragProjector.gd`, `scripts/ui/BodyRingDragController.gd`, `scripts/ui/Main.gd`, `scripts/ui/DragHandlesOverlay.gd`, `scripts/tools/ScreenDragProjectorTest.gd` + tscn, `scripts/tools/EditorDragEmissionTest.gd`

- [ ] **Step 1: 실패하는 카메라 투영 테스트.** `ScreenDragProjectorTest.gd`:
  - 기본 카메라에서 평면 `point = Vector3.ZERO`, `normal = Vector3.BACK` 위로 같은 마우스 위치를 두 번 투영하면 `Vector3.ZERO` 반환.
  - 카메라 yaw를 35도 돌린 상태에서 screen-right 드래그는 반환 델타의 local x 성분이 양수, screen-up 드래그는 local y 성분이 양수.
  - 같은 screen delta에서 카메라를 가까이 둔 경우의 world delta 길이가 멀리 둔 경우보다 작아야 한다(zoom/거리 반영).
- [ ] **Step 2: `ScreenDragProjector.gd` 구현.**
  - `static func screen_delta_on_plane(camera: Camera3D, from_pos: Vector2, to_pos: Vector2, plane_point: Vector3, plane_normal: Vector3) -> Vector3`
  - 내부에서 `camera.project_ray_origin(pos)` / `camera.project_ray_normal(pos)`를 사용해 이전/현재 ray를 만든다.
  - `var n := plane_normal.normalized(); var plane := Plane(n, n.dot(plane_point))`로 평면을 만들고 `plane.intersects_ray(origin, normal)` 결과 두 개가 모두 `Vector3`일 때 `to_hit - from_hit` 반환, 하나라도 실패하면 `Vector3.ZERO` 반환.
- [ ] **Step 3: 컨트롤러 구현.** `FishFinDragController.gd`의 입력 흐름을 본떠 작성하되 픽셀 상수 변환은 쓰지 않는다:
  - `_pick_handle(mouse_pos)`: `fish.get_body_ring_handles()`의 모든 (ring, part) 점을 `camera.unproject_position`으로 투영, 반경 28px 내 최근접 선택. center보다 top/bottom 우선(겹칠 때 silhouette 끝점이 잡히도록 part별 우선순위 가중치).
  - 프레스: 핸들 선택 + `ring_handle_selected(ring_id)` emit (Main이 `body_editor_panel.select_ring_by_id`로 연결 → 기존 가이드 하이라이트/패널 동기화 재사용).
  - 모션: 현재 핸들의 `fish.get_body_ring_drag_plane(ring_id, part)`를 조회하고 `ScreenDragProjector.screen_delta_on_plane(camera, previous_mouse_pos, current_mouse_pos, plane.point, plane.normal)`로 월드 델타를 계산해 누적한다.
  - `_process`: 누적 델타가 0이 아니면 프레임당 1회만 `fish.drag_ring_handle(ring_id, part, accumulated_world_delta)` 호출 후 누적값을 비운다. `rebuild()` 후 핸들 좌표가 바뀌므로 다음 모션에서는 plane을 다시 조회한다.
  - 릴리즈: `parameters_changed.emit(fish.parameters.duplicate(true))` 1회. `camera_controller.set_drag_suppressed` 연동 동일.
- [ ] **Step 4: Main 통합.** 바디 편집 토글 활성 시 `BodyRingDragController.set_enabled(true)`, `FishFinDragController.set_enabled(false)`가 되도록 `_sync_edit_input_state`를 확장한다. 머리/핀 편집 모드에서는 반대로 BodyRingDragController를 비활성화한다. 기존 `_on_preview_gui_input`의 링 클릭-선택 블록은 컨트롤러의 프레스 픽킹과 중복되므로 제거하고 컨트롤러 시그널로 대체. `parameters_changed`는 `_apply_parameters_from_editor`로 연결(기존 코얼레싱 경로).
- [ ] **Step 5: 오버레이.** 바디 편집 모드에서 호버 중인 링 핸들을 `DragHandlesOverlay`가 원형 하이라이트로 표시 (fin 핸들 호버 표시 코드 재사용; 3D 가이드 구체는 그대로 두고 2D 하이라이트만 추가). body 모드가 아니면 링 핸들을 그리지 않는다.
- [ ] **Step 6: 커밋/스로틀 규약 테스트.** `EditorDragEmissionTest.gd`에 BodyRingDragController 케이스 추가:
  - 프레스 후 mouse motion N회 직후에는 `parameters_changed` emit 0회이며 `fish.drag_ring_handle` 호출도 0회.
  - `_process` 1회 후 `fish.drag_ring_handle` 호출 1회.
  - 추가 motion N회 + `_process` 1회마다 호출은 1회만 증가.
  - 릴리즈 시 `parameters_changed` emit 1회.
- [ ] **Step 7:** `-Filter ScreenDragProjectorTest`, `-Filter EditorDragEmissionTest`, `-Filter EditModeExclusivityTest`, `-Filter DragHandlesTest` 통과 → 커밋 `"Drag body ring handles in preview"`

### Task 4: 턱 관절 · 혹 드래그 핸들

**Files:** `scripts/creature/FishRig.gd`, `scripts/ui/FishFinDragController.gd`, `scripts/ui/DragHandlesOverlay.gd`, `scripts/tools/HeadHandleDragTest.gd` + tscn, `scripts/tools/DragHandlesTest.gd`

- [ ] **Step 1: 실패하는 테스트.** `HeadHandleDragTest.gd`:
  - 기본 fish에서 `get_drag_handles()`에 `"jaw_hinge"` 포함(`jaw_hinge_valid`일 때), 좌표가 `get_jaw_hinge_world()`와 일치.
  - `head_bump_height = 0.3`이면 `"head_bump"` 포함, 0.0이면 미포함.
  - `move_jaw_hinge(Vector3(0.05, 0.02, 0.0))` 후 `jaw_hinge_x`/`jaw_hinge_y`가 머리 로컬 단위로 증가하고 clamp(-0.8..1.0 / -0.4..0.4) 준수, `get_jaw_hinge_world()`가 실제로 이동.
  - `move_head_bump(Vector3(0.1, 0.05, 0.0))` 후 `head_bump_pos`(+x 방향)·`head_bump_height`(+y 방향) 변경 및 clamp(-0.5..0.5 / 0.0..0.8).
- [ ] **Step 2: FishRig 구현.**
  - `get_drag_handles()`에 두 핸들 추가 (`jaw_hinge_valid` / `head_bump_height > 0.001` 조건).
  - `move_jaw_hinge(world_delta: Vector3)`: 월드 델타를 `head_node.global_basis.inverse()`로 머리 로컬로 변환 후 `jaw_hinge_x/_y`에 가산·clamp. 갱신은 입 파라미터 슬라이더가 타는 것과 같은 재구축 경로 사용 — FishRig 내부에서 입/턱만 다시 만드는 좁은 함수가 있으면 그것을, 없으면 `rebuild()`를 호출하되 컨트롤러 쪽 프레임 스로틀에 의존.
  - `move_head_bump(world_delta: Vector3)`: 머리 로컬 변환 후 `head_bump_pos += local.x / (머리 길이 스케일)`, `head_bump_height += local.y / (머리 높이 스케일)`. 스케일은 `get_head_bump_world()`와 역함수 관계가 되게 동일 계산식 공유.
  - `get_head_bump_world()`: 기존 `_head_bump_indicator_world()`가 있으면 그 계산식을 공개 메서드로 이동/재사용하고, `get_indicator_world("head_bump_*")`도 같은 메서드를 호출하게 해 표시 위치와 드래그 핸들 위치가 갈라지지 않게 한다.
  - `get_head_drag_plane(handle_id: String) -> Dictionary`: `jaw_hinge`/`head_bump`의 현재 월드 위치를 `point`, `head_node.global_transform.basis.z.normalized()`를 `normal`로 반환한다.
- [ ] **Step 3: 컨트롤러/오버레이.** `FishFinDragController`가 `"jaw_hinge"`/`"head_bump"` 드래그 시 `ScreenDragProjector.screen_delta_on_plane` + `fish.get_head_drag_plane(handle_id)`로 월드 델타를 만들고, 그 월드 델타를 `move_jaw_hinge(world_delta)` / `move_head_bump(world_delta)`에 넘긴다. `DragHandlesOverlay._should_draw_handle`: 두 핸들은 `draw_head`일 때만. 컨트롤러에도 같은 모드 필터 적용 — `allowed_handle_filter: Callable`을 Main이 모드 전환 시 주입하고 `_pick_handle`에서 먼저 검사해, 머리 편집 모드가 아닐 때 `jaw_hinge`/`head_bump`가 픽킹되지 않게 한다. 바디 편집 모드에서는 `FishFinDragController.enabled == false`이므로 head/fin 핸들 클릭·드래그가 모두 차단되어야 한다.
- [ ] **Step 4:** `DragHandlesTest.gd`에 신규 핸들 존재/모드 필터 케이스 추가:
  - fin 모드에서 포인터가 `jaw_hinge` 위에 있어도 `_pick_handle` 결과가 빈 문자열.
  - head 모드에서 같은 포인터는 `jaw_hinge` 선택.
  - body 모드에서 `FishFinDragController.enabled == false`이고 `DragHandlesOverlay`가 head/fin 핸들을 표시하지 않음.
  - 카메라 yaw 35도 + 줌 변경 상태에서 jaw/head_bump screen-up 드래그가 화면상 위쪽 이동으로 보이고 대응 파라미터가 양수 방향으로 변경.
- [ ] **Step 5:** `-Filter HeadHandleDragTest`, `-Filter DragHandlesTest`, `-Filter ScreenDragProjectorTest`, `-Filter JawLinkageTest` 통과 → 커밋 `"Add jaw hinge and head bump drag handles"`

### Task 5: Pick-to-Edit (클릭 → 패널 섹션 포커스)

**Files:** `scripts/ui/HeadEditorPanel.gd`, `scripts/ui/FinEditorPanel.gd`, `scripts/ui/FishFinDragController.gd`, `scripts/ui/Main.gd`, `scripts/tools/PickToEditTest.gd` + tscn

- [ ] **Step 1: 실패하는 테스트.** `PickToEditTest.gd`:
  - `HeadEditorPanel.focus_key("jaw_hinge_x")` 호출 후 "입" 섹션 body가 `visible == true`, 반환된 행 Control이 해당 키의 행.
  - 접혀 있던 섹션이 펼쳐지고 `section_expanded["입"] == true`로 기록됨.
  - `FinEditorPanel.select_slot("pectoral")` 후 `selected_slot == "pectoral"`이고 슬롯 옵션 UI가 동기화됨.
- [ ] **Step 2: 패널 API.**
  - `HeadEditorPanel.focus_key(key) -> Control`: `FISH_SECTIONS`에서 key가 속한 섹션 탐색 → 해당 헤더 `button_pressed = true`(기존 `apply` 람다가 body 표시+상태 기록) → `numeric_sliders[key]`의 행 반환. 키가 현재 비표시(`_should_show_fish_numeric_key` false)면 null 반환.
  - `FinEditorPanel.select_slot(slot_id)`: `selected_slot` 변경 + `_refresh_controls()`.
- [ ] **Step 3: 클릭 감지.** `FishFinDragController`에 `signal handle_clicked(handle_id)` 추가 — 프레스 후 누적 이동이 ~4px 미만인 릴리즈에서 emit (드래그와 구분).
- [ ] **Step 4: Main 라우팅.** `handle_clicked` 핸들러에서 매핑 적용:
  - `eye_l`/`eye_r` → `head_editor_panel.focus_key("eye_position_x")`
  - `operculum` → `focus_key("operculum_position_x")`, `jaw_hinge` → `focus_key("jaw_hinge_x")`, `head_bump` → `focus_key("head_bump_pos")`
  - 핀 핸들(`dorsal*`, `anal`, `pelvic`, `pectoral`) → `fin_editor_panel.select_slot(...)`
  - 반환된 행이 있으면 `editor_panel_scroll.ensure_control_visible(row)`.
  - BodyRingDragController의 `ring_handle_selected`는 이미 패널 동기화를 하므로 추가 라우팅 불필요.
  - body 편집 모드에서는 `FishFinDragController`가 비활성화되어 `handle_clicked`가 발생하지 않아야 한다. 링 선택은 오직 `BodyRingDragController.ring_handle_selected`에서만 처리한다.
- [ ] **Step 5:** `-Filter PickToEditTest`, `-Filter HeadEditorPanelTest`, `-Filter FinEditorPanelTest` 통과 → 커밋 `"Focus panel sections from preview clicks"`

### Task 6: 최종 검증

- [ ] 신규 4개 테스트(`BodyRingDragTest`, `ScreenDragProjectorTest`, `HeadHandleDragTest`, `PickToEditTest`) + `DragHandlesTest`, `FinDragTest`, `EditorDragEmissionTest`, `EditModeExclusivityTest`, `BodyEditorPanelTest`, `RingHeightDecoupleTest`, `JawLinkageTest`, `EyeAttachmentTest` 개별 통과.
- [ ] 전체 스위트 `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` 통과.
- [ ] 수동 확인 항목(작업자 메모): 카메라를 회전/줌한 뒤에도 바디 모드에서 링 top을 화면 위로 드래그하면 top이 화면 위로 움직이는가, 링 center를 화면 오른쪽으로 드래그하면 center가 화면 오른쪽으로 움직이는가, 드래그 중 카메라가 회전하지 않는가, 머리 모드에서 턱 핸들 드래그 중 입이 따라오는가, 바디/핀 모드에서 턱 핸들이 보이지도 잡히지도 않는가.

## Out of Scope

- 상/하 폭(`top_width`/`bottom_width`)의 드래그 편집 — 측면 카메라에서 z축 폭 드래그가 직관적이지 않으므로 3단계 폭 뷰 에디터에서 처리.
- 링 추가/삭제의 프리뷰 직접 조작 (3단계 실루엣 에디터에서 처리).
- 슬라이더 검색·기본값 마커 (1단계 계획).

## Self-Review

- 드래그 커밋 규약·모드 배타성·clamp 단일 출처가 계약으로 고정됨.
- 기존 클릭-선택과 신규 드래그의 중복 입력 경로 제거를 명시.
- 컨트롤러 픽킹의 모드 필터 누락(핀 모드에서 턱 픽킹) 회귀를 사전 차단.
- 카메라 회전/줌 상태의 방향감각 보장을 `ScreenDragProjectorTest`와 수동 확인 항목으로 고정.
- rebuild 비용은 프레임 스로틀 테스트로 고정하고, 좁은 재구축 경로 탐색은 작업자 재량.
