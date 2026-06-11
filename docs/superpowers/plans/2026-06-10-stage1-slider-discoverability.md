# 1단계: 슬라이더 탐색성 개선 구현 계획 (검색 · 기본값 마커 · 프리뷰 인디케이터)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 100개가 넘는 파라미터 슬라이더 사이에서 "원하는 항목 찾기"와 "이 슬라이더가 뭘 바꾸는지 알기"를 즉시 해결한다. 슬라이더 검색 필터, 기본값 눈금/더블클릭 리셋/변경값 강조, 슬라이더 조작 시 프리뷰 부위 인디케이터 세 가지를 추가한다.

**Architecture:** 모든 패널의 숫자 슬라이더 행은 `UiRows.add_labeled_slider`가 단독으로 생성하므로, 기본값 눈금·리셋·변경 마커는 `UiRows` 한 곳에 구현하고 각 패널은 기본값만 공급한다. 검색/필터는 패널별 행 레지스트리(`numeric_sliders`)를 확장해 행 가시성만 토글한다. 프리뷰 인디케이터는 기존 턱 관절 마커 경로(`HeadEditorPanel.numeric_slider_changed` → `Main._on_head_numeric_slider_changed` → `DragHandlesOverlay.show_jaw_hinge`)를 키→월드좌표 테이블 방식으로 일반화한다.

**Tech Stack:** Godot 4 GDScript, 기존 CLI 테스트 러너 `tools/run_godot_cli_tests.ps1`, `scripts/ui` 패널들.

**전제:** `codex/directional-body-head-sculpt-controls` 브랜치의 방향별 스컬프트 작업(`top_width`/`bottom_width`, 평면화 키)이 머지된 상태를 기준으로 한다.

---

## Scope Contract

- 슬라이더 행의 자식 순서 `[Label, HSlider, value Label]`은 절대 변경하지 않는다. 여러 테스트가 `row.get_child(0)`/`get_child(1)` 순서에 의존한다 (`UiRows.gd` 상단 주석 참고). 눈금은 슬라이더의 `draw` 콜백으로 그리고, 변경 마커는 이름 Label의 테마 색 오버라이드로 표현한다. 행에 자식 노드를 추가하지 않는다.
- 각 패널의 `numeric_sliders` 딕셔너리에서 기존 키 `"slider"`, `"label"`은 유지한다. 새 키 추가만 허용.
- 검색창과 "변경만 보기" 토글은 행 가시성만 바꾼다. 파라미터 값·시그널 방출에는 영향이 없어야 한다.
- 기본값이 알려지지 않은 키(예: ParameterPanel의 동적 키)는 눈금/리셋/변경 마커를 조용히 생략한다. 오류·경고를 내지 않는다.
- 인디케이터는 표시 전용이다. 파라미터를 변경하지 않으며, 알 수 없는 키에 대해 `Vector3.INF`를 반환하고 아무것도 그리지 않는다.
- 기존 `show_jaw_hinge` 동작(턱 힌지 슬라이더 조작 시 마커 + 자동 숨김 타이머)은 일반화된 경로 위에서 동일하게 유지된다.

## File Structure

- Modify `scripts/ui/UiRows.gd`: 기본값 눈금, 더블클릭 리셋, 변경 마커, 필터 행 빌더.
- Modify `scripts/ui/HeadEditorPanel.gd`: 기본값 공급, 검색/변경만 보기, `numeric_slider_changed`는 기존 그대로.
- Modify `scripts/ui/BodyEditorPanel.gd`: 기본값 공급, 검색/변경만 보기, `numeric_slider_changed(key)` 시그널 신설.
- Modify `scripts/ui/FinEditorPanel.gd`: 기본값 공급, 검색/변경만 보기, `numeric_slider_changed(key)` 시그널 신설.
- Modify `scripts/ui/ParameterPanel.gd`: 검색/변경만 보기(기본값 눈금은 생략 가능).
- Modify `scripts/creature/FishRig.gd`: `get_indicator_world(key)` 추가.
- Modify `scripts/ui/DragHandlesOverlay.gd`: `show_jaw_hinge` → 일반 `indicator_key` 기반 표시로 대체.
- Modify `scripts/ui/Main.gd`: 인디케이터 와이어링 일반화 (`jaw_hinge_marker_timer` → `indicator_timer`).
- Modify `scripts/ui/UiText.gd`: 검색 placeholder, "변경만 보기" 라벨 등 신규 문구.
- Add `scripts/tools/UiRowsDefaultsTest.gd` + `scenes/UiRowsDefaultsTest.tscn`.
- Add `scripts/tools/SliderSearchFilterTest.gd` + `scenes/SliderSearchFilterTest.tscn`.
- Add `scripts/tools/SliderIndicatorTest.gd` + `scenes/SliderIndicatorTest.tscn`.
- Modify `scripts/tools/HeadEditorPanelTest.gd`, `scripts/tools/BodyEditorPanelTest.gd`, `scripts/tools/DragHandlesTest.gd`: 신규 동작 커버.

---

### Task 1: UiRows에 기본값 눈금 · 더블클릭 리셋 · 변경 마커 추가

**Files:** `scripts/ui/UiRows.gd`, `scripts/tools/UiRowsDefaultsTest.gd`, `scenes/UiRowsDefaultsTest.tscn`

- [x] **Step 1: 실패하는 테스트 작성.** `UiRowsDefaultsTest.gd`: 컨테이너에 `add_labeled_slider`로 `{"min":0.0,"max":1.0,"step":0.01,"default":0.4,"value":0.8}` 행을 만들고 다음을 assert:
  - 반환 딕셔너리에 `"row"`, `"slider"`, `"value_label"`, `"name_label"` 키 존재.
  - `UiRows.reset_row_to_default(widgets)` 호출 후 `slider.value == 0.4`.
  - `UiRows.is_changed_from_default(widgets)`가 리셋 전 `true`, 후 `false`.
  - `default` 없는 config로 만든 행에서 `reset_row_to_default`가 no-op이고 오류가 없음.
  - 행 자식 수가 정확히 3, 순서가 Label/HSlider/Label.
- [x] **Step 2: 테스트 실행, 실패 확인.** `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UiRowsDefaultsTest`
- [x] **Step 3: 구현.** `add_labeled_slider`에 추가:
  - config `"default"`(옵션). 있으면 행 메타에 저장(`row.set_meta("default_value", ...)` 또는 반환 딕셔너리).
  - 반환 딕셔너리에 `"name_label"` 추가 (기존 키 유지).
  - 눈금: `slider.draw.connect(...)`로 `(default-min)/(max-min)` 비율 위치에 폭 2px, 높이 ~8px 세로선을 반투명 색으로 그림. `slider.size.x` 기준.
  - 더블클릭 리셋: `slider.gui_input.connect(...)`에서 `InputEventMouseButton.double_click`이면 `reset_row_to_default` 호출.
  - `static func reset_row_to_default(widgets: Dictionary) -> void`: default 있으면 `slider.value = default` (value_changed 시그널이 기존 패널 핸들러를 타게 둔다).
  - `static func is_changed_from_default(widgets: Dictionary) -> bool`: `absf(value - default) > step * 0.5` 기준. default 없으면 `false`.
  - `static func update_changed_marker(widgets: Dictionary) -> void`: 변경 시 name_label에 `add_theme_color_override("font_color", 강조색)`, 아니면 `remove_theme_color_override`.
- [x] **Step 4: 테스트 통과 확인 후 커밋.** `git add scripts/ui/UiRows.gd scripts/tools/UiRowsDefaultsTest.gd scenes/UiRowsDefaultsTest.tscn` (+ 생성된 `.uid` 사이드카) → `git commit -m "Add slider default tick, reset, changed marker"`

### Task 2: 패널별 기본값 공급 및 변경 마커 적용

**Files:** `scripts/ui/HeadEditorPanel.gd`, `scripts/ui/BodyEditorPanel.gd`, `scripts/ui/FinEditorPanel.gd`, 기존 패널 테스트들

- [x] **Step 1: 패널 테스트 확장 (실패 확인).**
  - `HeadEditorPanelTest.gd`: `panel.set_numeric_parameter("head_size", 0.9)` 후 `panel.is_row_changed("head_size") == true`, `_default_numeric("head_size")` 값으로 리셋 후 `false`.
  - `BodyEditorPanelTest.gd`: 동일 패턴을 `upper_height`로.
- [x] **Step 2: HeadEditorPanel.** `_add_numeric_row`에서 config에 `"default": _default_numeric(key)` 전달. `_refresh_controls`의 슬라이더 동기화 루프 끝에서 각 행에 `UiRows.update_changed_marker` 호출. 테스트용 공개 헬퍼 `func is_row_changed(key: String) -> bool` 추가.
  - 주의: `NUMERIC_KEYS`의 min이 0이 아닌 키(`head_size` 등)는 `_default_numeric` fallback이 0.0을 반환하면 min 미만이 된다. `_default_numeric`이 0.0을 반환하면서 min > 0.0인 키는 default를 생략한다(또는 `_default_numeric`에 해당 키 기본값을 보강한다 — `snout_curve`, `head_top_curve` 등 0이 유효한 키와 구분할 것).
- [x] **Step 3: BodyEditorPanel.** 기본값 출처는 `BodyProfileScript.default_fish_rings()`에서 `selected_ring_id`와 같은 `id`를 가진 링. 링 선택이 바뀔 때마다 default가 달라지므로, `_add_numeric_row`에서 정적으로 넣지 말고 `_refresh_controls`에서 행 메타의 `default_value`를 갱신한 뒤 마커를 업데이트한다 (UiRows에 `set_row_default(widgets, value)` 헬퍼 추가). 사용자 추가 링(`id`가 default에 없음)은 default 생략.
- [x] **Step 4: FinEditorPanel.** `_numeric_value`가 사용하는 키별 fallback과 같은 출처로 default 공급. 구조는 HeadEditorPanel과 동일.
- [x] **Step 5: "변경만 보기" 토글.** 각 패널(Head/Body/Fin) 슬라이더 영역 상단에 CheckBox(`UiText` 신규 라벨 `"변경된 항목만"`). 켜면 `is_changed_from_default`가 false인 행 숨김. HeadEditorPanel은 섹션 body가 전부 숨겨지면 해당 섹션 header도 숨김. 토글 해제 시 원상 복구(섹션 펼침 상태 `section_expanded` 보존).
- [x] **Step 6: 테스트.** `-Filter HeadEditorPanelTest`, `-Filter BodyEditorPanelTest`, `-Filter FinEditorPanelTest` 모두 통과. 커밋 `"Supply slider defaults and changed markers per panel"`

### Task 3: 슬라이더 검색 필터

**Files:** 4개 패널, `scripts/ui/UiText.gd`, `scripts/tools/SliderSearchFilterTest.gd` + tscn

- [ ] **Step 1: 실패하는 테스트.** `SliderSearchFilterTest.gd`: HeadEditorPanel을 인스턴스화하고 `set_parameters({})` 후:
  - `panel.set_search_text("턱")` → `jaw_hinge_x` 행의 `row.visible == true`, `eye_size` 행은 숨김(행이 속한 섹션 body는 강제 표시 상태).
  - `panel.set_search_text("")` → 모든 행 복구, 섹션 펼침 상태가 검색 전과 동일.
  - 검색 중 `set_numeric_parameter` 호출이 정상 동작(필터가 값 경로를 막지 않음).
- [ ] **Step 2: 구현.**
  - `UiRows.add_filter_row(parent, placeholder) -> LineEdit` 헬퍼 (한 줄 LineEdit, `text_changed` 연결은 호출자가).
  - 각 패널에 `var search_text := ""` + `func set_search_text(text)` + `func _apply_row_filter()`. 매칭 기준: `UiText` 한글 라벨(이름 Label의 `text`)에 `contains` (대소문자 무시 불필요 — 한글). 매칭 규칙은 "변경만 보기"와 AND 결합.
  - HeadEditorPanel: 검색 활성 시 매칭 행을 포함한 섹션 body를 `visible = true`로 강제(헤더 `button_pressed`는 건드리지 않음), 검색 해제 시 `section_expanded` 기준으로 복원. `_sync_numeric_controls`가 행을 재생성한 직후 `_apply_row_filter()` 재호출.
  - BodyEditorPanel/FinEditorPanel/ParameterPanel: 동일 패턴 (ParameterPanel은 `sliders`/`section_bodies` 레지스트리 사용, `_ensure_section` 헤더 포함).
- [ ] **Step 3: 테스트 + 커밋.** `-Filter SliderSearchFilterTest`, 기존 패널 테스트 4종 통과 → `"Add slider search filter to editor panels"`

### Task 4: 프리뷰 인디케이터 일반화

**Files:** `scripts/creature/FishRig.gd`, `scripts/ui/DragHandlesOverlay.gd`, `scripts/ui/Main.gd`, 3개 패널, `scripts/tools/SliderIndicatorTest.gd` + tscn, `scripts/tools/DragHandlesTest.gd`

- [ ] **Step 1: 실패하는 테스트.** `SliderIndicatorTest.gd`: 기본 파라미터의 FishRig에서
  - `get_indicator_world("jaw_hinge_x")`가 유한 벡터이고 `get_jaw_hinge_world()`와 일치.
  - `get_indicator_world("eye_size")` 유한, `get_indicator_world("operculum_size")`는 `gill_mark=="operculum"`일 때만 유한.
  - `set_selected_body_ring("mid_body")` 후 `get_indicator_world("upper_height")`가 해당 링 상단점(= 링 가이드 top과 동일 좌표) 반환.
  - `get_indicator_world("no_such_key")`는 `Vector3.INF`.
- [ ] **Step 2: FishRig 구현.** `func get_indicator_world(key: String) -> Vector3`, prefix 테이블 기반:
  - `jaw_*`, `lower_jaw_*`, `mouth_*`, `lower_upper_ratio` → `get_jaw_hinge_world()`
  - `eye_*` → `eye_l.global_position`
  - `operculum_*` → `get_vector_edit_marker_world("operculum", Vector2(0.5, 0.0))`
  - `head_bump_*` → 신규 `get_head_bump_world()` (head_bump_pos를 머리 상단 호를 따라 월드 변환; 정확한 정점 추적이 아니어도 머리 상단 근사면 충분)
  - `snout_*`, `snout_appendage_length` → 머리 전방점(head_node 기준 -x 방향 최전방 근사)
  - `head_size`, `head_offset`, `head_flattening`, `head_top_*`, `head_belly_curve`, `forehead_slope`, `head_*_flatness` → `head_node.global_position`
  - 바디 링 키(`x`, `y_offset`, `upper_height`, `lower_height`, `width`, `top_width`, `bottom_width`, `*_flatness`, `roundness`, `sway_weight`) → `selected_body_ring_id` 링의 center/top/bottom 점 (upper→top, lower→bottom, 그 외→center). `_add_ring_guides`가 쓰는 좌표 계산을 헬퍼로 추출해 공유.
  - 그 외 → `Vector3.INF`
- [ ] **Step 3: 오버레이 교체.** `DragHandlesOverlay`: `show_jaw_hinge` 제거, `var indicator_key := ""` 추가. `_draw`에서 `indicator_key != ""`이면 `fish.get_indicator_world(indicator_key)`가 유한할 때 십자 마커 + `UiText` 라벨 텍스트 표시(기존 턱 힌지 마커 그리기 코드 재활용). `DragHandlesTest.gd`에서 `show_jaw_hinge` 참조를 `indicator_key`로 갱신.
- [ ] **Step 4: Main 와이어링.** `_on_head_numeric_slider_changed`를 `_on_editor_numeric_slider_changed(key)`로 일반화: `overlay.indicator_key = key`, 타이머 재시작(만료 시 `indicator_key = ""`). `jaw_hinge_marker_timer` → `indicator_timer`로 개명. BodyEditorPanel과 FinEditorPanel에 `numeric_slider_changed(key)` 시그널 추가(HeadEditorPanel `_add_numeric_row`의 emit 패턴 복제) 후 같은 핸들러에 연결. 오버레이 가시성: 인디케이터 활성 시 body 편집 모드에서도 오버레이가 보이도록 `_update_overlay_visibility` 조건에 `indicator_key != ""` 추가.
- [ ] **Step 5: 테스트 + 커밋.** `-Filter SliderIndicatorTest`, `-Filter DragHandlesTest`, `-Filter HeadEditorPanelTest` 통과 → `"Generalize slider preview indicators"`

### Task 5: 최종 검증

- [ ] 신규 4개 테스트 + `BodyEditorPanelTest`, `HeadEditorPanelTest`, `FinEditorPanelTest`, `ParameterPanelCategoryTest`, `ParameterPanelRangeTest`, `DragHandlesTest`, `EditModeExclusivityTest`, `EditorParameterSyncTest` 개별 실행 통과.
- [ ] 전체 스위트: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` (러너 종료 코드 기준; `Failed to read the root certificate store`는 무시).
- [ ] `git status --short`로 이 계획에 명시된 파일만 변경됐는지 확인.

## Out of Scope

- 드래그 핸들 신설·핸들 드래그로 파라미터 변경 (2단계 계획).
- 실루엣 커브 에디터, 옵션 썸네일 (3단계 계획).
- ParameterPanel의 키별 기본값 정의(눈금은 Head/Body/Fin 패널만).

## Self-Review

- 행 구조 불변 계약이 모든 Task에 반영됨.
- 기본값이 없는 키의 안전한 생략 경로 명시.
- 기존 턱 힌지 마커 동작이 일반화 경로에서 보존됨.
- 모든 신규 동작에 헤드리스 CLI 테스트가 대응됨.
