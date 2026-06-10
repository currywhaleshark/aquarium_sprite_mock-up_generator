# 2단계: 프리뷰 직접 조작 확장 구현 계획 (링 핸들 드래그 · 턱/혹 핸들 · Pick-to-Edit)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 슬라이더로만 가능하던 핵심 조작을 프리뷰에서 직접 드래그로 수행한다. ① 바디 링 가이드의 상/하/중심점 드래그로 `upper_height`/`lower_height`/`x`/`y_offset` 편집, ② 턱 관절(jaw hinge)·머리 혹(bump) 드래그 핸들, ③ 프리뷰에서 부위 클릭 시 해당 패널 섹션 자동 펼침+스크롤(Pick-to-Edit).

**Architecture:** 기존 직접 조작 인프라를 확장한다. `FishFinDragController`의 패턴(픽킹 → 라이브 드래그는 emit 없이 → 릴리즈 시 1회 `parameters_changed` emit, 카메라 드래그 억제)을 그대로 따른다. 바디 링은 이미 존재하는 3D 링 가이드(`FishRig._add_ring_guides`)와 클릭 선택(`Main._on_preview_gui_input`)을 드래그 가능한 핸들로 승격한다. 월드 델타→파라미터 델타 변환은 FishRig 안의 메서드(`drag_ring_handle`, `move_jaw_hinge`, `move_head_bump`)가 담당하고, 컨트롤러는 얇게 유지한다.

**Tech Stack:** Godot 4 GDScript, `tools/run_godot_cli_tests.ps1`, `scripts/ui` + `scripts/creature`.

**전제:** 1단계 계획(슬라이더 탐색성)과 독립적으로 구현 가능. 단, 1단계의 `DragHandlesOverlay.indicator_key` 변경이 먼저 머지됐다면 `show_jaw_hinge` 참조가 이미 제거된 상태이므로 충돌에 주의.

---

## Scope Contract

- 드래그 커밋 규약: 마우스 이동 중에는 rig만 갱신하고 `parameters_changed`를 emit하지 않는다. 릴리즈 시 1회 emit. (기존 `FishFinDragController` 및 `EditorDragEmissionTest`와 동일 규약.)
- 드래그로 만든 값은 패널 슬라이더와 동일한 clamp 범위를 따른다. 링 키 범위의 단일 출처를 `BodyProfile.gd`의 상수로 옮기고 `BodyEditorPanel.RING_NUMERIC_KEYS`가 이를 참조하게 한다 (UI→creature 역방향 의존 금지).
- 링 핸들 드래그는 해당 링의 대상 필드만 변경한다. top 드래그는 `upper_height`만, bottom은 `lower_height`만, center는 `x`/`y_offset`만.
- 라이브 드래그 중 rig 재구축은 프레임당 최대 1회로 스로틀한다 (델타 누적 → `_process`에서 적용).
- 편집 모드 배타성 유지: 링 핸들은 바디 편집 모드에서만, 턱/혹 핸들은 머리 편집 모드에서만 픽킹·표시된다. `EditModeExclusivityTest`가 깨지면 안 된다.
- Pick-to-Edit은 포커스(섹션 펼침+스크롤)만 수행하고 파라미터를 변경하지 않는다.
- 레거시 프리셋·기존 테스트 동작 불변. 핸들이 없는 상태(예: ray, 턱 없음)에서는 해당 핸들이 조용히 생략된다.

## File Structure

- Modify `scripts/creature/BodyProfile.gd`: 링 키 clamp 범위 상수 `RING_KEY_RANGES` 신설.
- Modify `scripts/ui/BodyEditorPanel.gd`: `RING_NUMERIC_KEYS`가 `BodyProfile.RING_KEY_RANGES` 참조.
- Modify `scripts/creature/FishRig.gd`: `get_body_ring_handles()`, `drag_ring_handle()`, `move_jaw_hinge()`, `move_head_bump()`, `get_head_bump_world()`, `get_drag_handles()` 확장.
- Add `scripts/ui/BodyRingDragController.gd`: 바디 링 핸들 픽킹/드래그 컨트롤러.
- Modify `scripts/ui/FishFinDragController.gd`: `jaw_hinge`/`head_bump` 분기, 모드별 핸들 필터, `handle_clicked` 시그널.
- Modify `scripts/ui/DragHandlesOverlay.gd`: 신규 핸들 표시(`_should_draw_handle` 확장), 링 핸들 호버 표시.
- Modify `scripts/ui/HeadEditorPanel.gd`: `focus_key(key) -> Control` (섹션 펼침 + 행 반환).
- Modify `scripts/ui/FinEditorPanel.gd`: `select_slot(slot_id)` 공개 메서드.
- Modify `scripts/ui/Main.gd`: BodyRingDragController 와이어링, 기존 클릭-선택 코드 이관, Pick-to-Edit 라우팅(`editor_panel_scroll.ensure_control_visible`).
- Add `scripts/tools/BodyRingDragTest.gd` + `scenes/BodyRingDragTest.tscn`.
- Add `scripts/tools/HeadHandleDragTest.gd` + `scenes/HeadHandleDragTest.tscn`.
- Add `scripts/tools/PickToEditTest.gd` + `scenes/PickToEditTest.tscn`.
- Modify `scripts/tools/DragHandlesTest.gd`, `scripts/tools/EditorDragEmissionTest.gd`: 신규 핸들/컨트롤러 커버.

---

### Task 1: 링 키 범위 단일 출처화

**Files:** `scripts/creature/BodyProfile.gd`, `scripts/ui/BodyEditorPanel.gd`

- [ ] **Step 1:** `BodyProfile.gd`에 `const RING_KEY_RANGES := {...}` 추가 — 현재 `BodyEditorPanel.RING_NUMERIC_KEYS`의 min/max/step을 그대로 이동.
- [ ] **Step 2:** `BodyEditorPanel.RING_NUMERIC_KEYS`를 `BodyProfileScript.RING_KEY_RANGES` 참조로 교체 (상수 → `static func` 또는 직접 참조; GDScript const 딕셔너리 참조 가능 여부 확인 후 적절한 형태 선택).
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
  - `drag_ring_handle(ring_id: String, part: String, world_delta: Vector3) -> void`: 월드 델타를 body 파라미터 단위로 변환 — 세로는 `body_height`로, 가로는 shell x 범위(`start_x..end_x`, `_build_shell_profile_from_rings` 참조)로 정규화. `parameters["body_profile"]["rings"]`를 직접 변형 후 `rebuild()`. clamp는 `BodyProfile.RING_KEY_RANGES`.
  - 주의: `rebuild()`가 가이드도 다시 만들므로 드래그 중 핸들 좌표 재조회 필요 — 컨트롤러가 매 프레임 `get_body_ring_handles()`를 다시 읽는 구조로 설계.
- [ ] **Step 3:** `-Filter BodyRingDragTest` 통과, `-Filter RingHeightDecoupleTest`·`-Filter ShellRigTest` 회귀 통과 → 커밋 `"Add draggable body ring handle API"`

### Task 3: BodyRingDragController + Main 와이어링

**Files:** `scripts/ui/BodyRingDragController.gd`, `scripts/ui/Main.gd`, `scripts/ui/DragHandlesOverlay.gd`, `scripts/tools/EditorDragEmissionTest.gd`

- [ ] **Step 1: 컨트롤러 구현.** `FishFinDragController.gd`(108줄)를 본떠 작성:
  - `_pick_handle(mouse_pos)`: `fish.get_body_ring_handles()`의 모든 (ring, part) 점을 `camera.unproject_position`으로 투영, 반경 28px 내 최근접 선택. center보다 top/bottom 우선(겹칠 때 silhouette 끝점이 잡히도록 part별 우선순위 가중치).
  - 프레스: 핸들 선택 + `ring_handle_selected(ring_id)` emit (Main이 `body_editor_panel.select_ring_by_id`로 연결 → 기존 가이드 하이라이트/패널 동기화 재사용).
  - 모션: 마우스 델타를 `DRAG_WORLD_PER_PIXEL`(기존 상수 0.004와 동일 환산) 기준 월드 델타로 바꿔 누적, `_process`에서 프레임당 1회 `fish.drag_ring_handle` 호출 (emit 없음).
  - 릴리즈: `parameters_changed.emit(fish.parameters.duplicate(true))` 1회. `camera_controller.set_drag_suppressed` 연동 동일.
- [ ] **Step 2: Main 통합.** 바디 편집 토글 활성 시 컨트롤러 입력 활성화(`_sync_edit_input_state` 확장). 기존 `_on_preview_gui_input`의 링 클릭-선택 블록은 컨트롤러의 프레스 픽킹과 중복되므로 제거하고 컨트롤러 시그널로 대체. `parameters_changed`는 `_apply_parameters_from_editor`로 연결(기존 코얼레싱 경로).
- [ ] **Step 3: 오버레이.** 바디 편집 모드에서 호버 중인 링 핸들을 `DragHandlesOverlay`가 원형 하이라이트로 표시 (fin 핸들 호버 표시 코드 재사용; 3D 가이드 구체는 그대로 두고 2D 하이라이트만 추가).
- [ ] **Step 4: 커밋 규약 테스트.** `EditorDragEmissionTest.gd`에 BodyRingDragController 케이스 추가: 모션 N회 동안 emit 0회, 릴리즈 시 1회.
- [ ] **Step 5:** `-Filter EditorDragEmissionTest`, `-Filter EditModeExclusivityTest`, `-Filter DragHandlesTest` 통과 → 커밋 `"Drag body ring handles in preview"`

### Task 4: 턱 관절 · 혹 드래그 핸들

**Files:** `scripts/creature/FishRig.gd`, `scripts/ui/FishFinDragController.gd`, `scripts/ui/DragHandlesOverlay.gd`, `scripts/tools/HeadHandleDragTest.gd` + tscn, `scripts/tools/DragHandlesTest.gd`

- [ ] **Step 1: 실패하는 테스트.** `HeadHandleDragTest.gd`:
  - 기본 fish에서 `get_drag_handles()`에 `"jaw_hinge"` 포함(`jaw_hinge_valid`일 때), 좌표가 `get_jaw_hinge_world()`와 일치.
  - `head_bump_height = 0.3`이면 `"head_bump"` 포함, 0.0이면 미포함.
  - `move_jaw_hinge(0.05, 0.02)` 후 `jaw_hinge_x`/`jaw_hinge_y`가 머리 로컬 단위로 증가하고 clamp(-0.8..1.0 / -0.4..0.4) 준수, `get_jaw_hinge_world()`가 실제로 이동.
  - `move_head_bump(0.1, 0.05)` 후 `head_bump_pos`(+x 방향)·`head_bump_height`(+y 방향) 변경 및 clamp(-0.5..0.5 / 0.0..0.8).
- [ ] **Step 2: FishRig 구현.**
  - `get_drag_handles()`에 두 핸들 추가 (`jaw_hinge_valid` / `head_bump_height > 0.001` 조건).
  - `move_jaw_hinge(delta_x, delta_y)`: 월드 델타를 `head_node.global_basis.inverse()`로 머리 로컬로 변환 후 `jaw_hinge_x/_y`에 가산·clamp. 갱신은 입 파라미터 슬라이더가 타는 것과 같은 재구축 경로 사용 — FishRig 내부에서 입/턱만 다시 만드는 좁은 함수가 있으면 그것을, 없으면 `rebuild()`를 호출하되 컨트롤러 쪽 프레임 스로틀에 의존.
  - `move_head_bump(delta_x, delta_y)`: 머리 로컬 변환 후 `head_bump_pos += local.x / (머리 길이 스케일)`, `head_bump_height += local.y / (머리 높이 스케일)`. 스케일은 `get_head_bump_world()`와 역함수 관계가 되게 동일 계산식 공유.
  - `get_head_bump_world()`: 1단계 계획과 중복 — 이미 구현돼 있으면 재사용, 없으면 여기서 추가.
- [ ] **Step 3: 컨트롤러/오버레이.** `FishFinDragController._apply_handle_drag`에 `"jaw_hinge"` → `move_jaw_hinge`, `"head_bump"` → `move_head_bump` 분기. `DragHandlesOverlay._should_draw_handle`: 두 핸들은 `draw_head`일 때만. 컨트롤러에도 같은 모드 필터 적용 — `allowed_handle_filter: Callable`을 Main이 모드 전환 시 주입해, 머리 편집 모드가 아닐 때 `jaw_hinge`/`head_bump`가 픽킹되지 않게 한다 (현재 컨트롤러는 `get_drag_handles()` 전체에서 픽킹하므로 필터가 없으면 핀 모드에서 턱이 잡히는 회귀 발생).
- [ ] **Step 4:** `DragHandlesTest.gd`에 신규 핸들 존재/모드 필터 케이스 추가. `-Filter HeadHandleDragTest`, `-Filter DragHandlesTest`, `-Filter JawLinkageTest` 통과 → 커밋 `"Add jaw hinge and head bump drag handles"`

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
- [ ] **Step 5:** `-Filter PickToEditTest`, `-Filter HeadEditorPanelTest`, `-Filter FinEditorPanelTest` 통과 → 커밋 `"Focus panel sections from preview clicks"`

### Task 6: 최종 검증

- [ ] 신규 3개 테스트 + `DragHandlesTest`, `FinDragTest`, `EditorDragEmissionTest`, `EditModeExclusivityTest`, `BodyEditorPanelTest`, `RingHeightDecoupleTest`, `JawLinkageTest`, `EyeAttachmentTest` 개별 통과.
- [ ] 전체 스위트 `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` 통과.
- [ ] 수동 확인 항목(작업자 메모): 바디 모드에서 링 top 드래그 중 카메라가 회전하지 않는가, 머리 모드에서 턱 핸들 드래그 중 입이 따라오는가, 핀 모드에서 턱 핸들이 보이지도 잡히지도 않는가.

## Out of Scope

- 상/하 폭(`top_width`/`bottom_width`)의 드래그 편집 — 측면 카메라에서 z축 폭 드래그가 직관적이지 않으므로 3단계 폭 뷰 에디터에서 처리.
- 링 추가/삭제의 프리뷰 직접 조작 (3단계 실루엣 에디터에서 처리).
- 슬라이더 검색·기본값 마커 (1단계 계획).

## Self-Review

- 드래그 커밋 규약·모드 배타성·clamp 단일 출처가 계약으로 고정됨.
- 기존 클릭-선택과 신규 드래그의 중복 입력 경로 제거를 명시.
- 컨트롤러 픽킹의 모드 필터 누락(핀 모드에서 턱 픽킹) 회귀를 사전 차단.
- rebuild 비용은 프레임 스로틀로 1차 대응, 좁은 재구축 경로 탐색은 작업자 재량.
