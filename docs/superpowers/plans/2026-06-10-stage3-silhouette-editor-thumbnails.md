# 3단계: 바디 실루엣 커브 에디터 · 옵션 썸네일 그리드 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ① 링별 슬라이더 13개 × 링 8개 대신 몸통 실루엣을 2D 커브로 직접 그리는 `BodySilhouetteEditor`를 바디 패널에 추가한다(측면 뷰: 상/하 높이·위치, 폭 뷰: 상/하 반원 폭). ② 머리 형태 등 enum 드롭다운을 미니 렌더 썸네일 그리드로 교체한다.

**Architecture:** 실루엣 에디터는 `FinVectorEditor.gd`(포인트 드래그/세그먼트 클릭 추가/우클릭 삭제, 정규화↔픽셀 좌표 변환, 시그널로 점 배열 방출)의 검증된 패턴을 따르되, 점 배열 대신 `body_profile.rings`를 직접 다룬다. 값 변경은 전부 기존 `BodyEditorPanel.set_ring_parameter` / `select_ring_by_id` / 링 추가·삭제 메서드를 경유해 emit·코얼레싱·정규화 경로를 재사용한다. 썸네일은 `MouthShot.gd`의 SubViewport 오프스크린 렌더 패턴으로 사전 생성해 리포지토리에 체크인하고, 런타임에는 텍스처 로드만 한다(런타임 렌더 없음).

**Tech Stack:** Godot 4 GDScript, `tools/run_godot_cli_tests.ps1`, 썸네일 생성은 비-headless 1회 실행 도구.

**전제:** `top_width`/`bottom_width` 링 필드(directional sculpt 작업)가 머지된 상태. 1·2단계와 독립적으로 구현 가능하나, 2단계의 `BodyProfile.RING_KEY_RANGES`가 있으면 그것을 clamp 출처로 사용한다(없으면 `BodyEditorPanel.RING_NUMERIC_KEYS` 값을 복제하지 말고 2단계 Task 1을 선행할 것).

---

## Scope Contract

- 실루엣 에디터는 rings 데이터의 또 다른 뷰일 뿐이다. 슬라이더는 제거하지 않고 정밀 조정용으로 유지하며, 에디터 드래그 ↔ 슬라이더 ↔ 프리셋이 항상 같은 값을 보여야 한다.
- 모든 변형은 `BodyEditorPanel`의 기존 변이 메서드를 경유한다. 에디터가 `parameters_changed`를 직접 emit하지 않는다.
- 측면 뷰 매핑 계약: 위젯 x ∈ [0,1] = `ring.x`, 위 곡선의 y = `y_offset + upper_height`, 아래 곡선의 y = `y_offset - lower_height`. 폭 뷰: 위쪽 곡선 = `top_width`, 아래쪽 곡선 = `bottom_width`. 두 값 모두 좌우 z 반경에 대칭 적용되며, 한쪽 측면만 넓히는 편집은 제공하지 않는다.
- 링 드래그 시 `x`는 이웃 링 사이로 clamp되어 정렬 순서가 유지된다 (`_sort_rings_by_x` 불변).
- 링 삭제는 `BodyProfile.MIN_RING_COUNT` 미만으로 내려가지 않는다 (기존 `delete_selected_ring` 규약).
- 썸네일 그리드는 텍스처가 없는 값에 대해 텍스트 버튼으로 폴백한다. 썸네일 부재가 기능을 막지 않는다.
- 드래그 중 emit 빈도는 슬라이더와 동일 수준(변경마다 emit → Main의 코얼레싱이 처리). 릴리즈-시-1회 규약은 프리뷰 핸들에만 적용되는 규약이며 패널 내 위젯에는 적용하지 않는다(기존 `FinVectorEditor`와 동일).

## File Structure

- Add `scripts/ui/BodySilhouetteEditor.gd`: 2D 실루엣 커브 에디터 Control.
- Modify `scripts/ui/BodyEditorPanel.gd`: 에디터 임베드(패널 최상단), 뷰 전환 버튼, 데이터 동기화.
- Modify `scripts/ui/Main.gd`: (필요 시) 에디터 ↔ 프리뷰 링 선택 동기화 — 기존 `ring_selected` 경로 재사용 확인.
- Add `scripts/ui/ThumbnailOptionGrid.gd`: 썸네일 옵션 그리드 Control.
- Modify `scripts/ui/HeadEditorPanel.gd`: `head_shape`(필수), `eye_style`·`mouth_type`(썸네일 존재 시) 드롭다운 → 그리드 교체.
- Add `scripts/tools/OptionThumbShot.gd` + `scenes/OptionThumbShot.tscn`: 썸네일 일괄 생성 도구 (비-headless, `*Test` 아님 — 스위트에서 제외됨).
- Add `assets/option_thumbs/`: 생성된 PNG 체크인 (`head_shape/<value>.png` 등).
- Add `scripts/tools/BodySilhouetteEditorTest.gd` + `scenes/BodySilhouetteEditorTest.tscn`.
- Add `scripts/tools/ThumbnailOptionGridTest.gd` + `scenes/ThumbnailOptionGridTest.tscn`.
- Modify `scripts/tools/BodyEditorPanelTest.gd`, `scripts/tools/HeadEditorPanelTest.gd`: 통합 동작 커버.
- Modify `scripts/ui/UiText.gd`: 뷰 전환 라벨("측면", "위에서"), 그리드 캡션 재사용 확인.

---

### Task 1: BodySilhouetteEditor — 측면 뷰 읽기/드래그

**Files:** `scripts/ui/BodySilhouetteEditor.gd`, `scripts/tools/BodySilhouetteEditorTest.gd` + tscn

테스트 용이성을 위해 마우스 이벤트 합성 대신 공개 조작 API를 두고, `_gui_input`은 그 API를 호출하는 얇은 층으로 만든다.

- [x] **Step 1: 실패하는 테스트.** `BodySilhouetteEditorTest.gd`:
  - `editor.set_rings(BodyProfileScript.ensure_body_profile({})["rings"])` 후 `editor.handle_norm_position("mid_body", "top")`이 매핑 계약대로 (`x`, `y_offset + upper_height`) 반환.
  - `editor.apply_handle_drag("mid_body", "top", Vector2(0.0, 0.1))` 호출 시 `signal ring_value_changed(ring_id, key, value)`가 `upper_height` 키로 emit되고 다른 키로는 emit되지 않음.
  - `"center"` 드래그는 `x`·`y_offset` 두 번의 `ring_value_changed`로 emit, `x`가 이웃 사이로 clamp.
  - `editor.request_select("head")` → `signal ring_pick_requested(ring_id)` emit.
  - `editor.request_add_at(0.5)` → `signal ring_add_requested(x)` emit; `editor.request_delete("mid_body")` → `signal ring_delete_requested(ring_id)` emit. (추가/삭제 판단·실행은 패널 몫.)
- [x] **Step 2: 구현.**
  - 상태: `rings: Array`(읽기 전용 사본), `selected_ring_id: String`, `view_mode: String`("side"/"top" — 이 Task에서는 side만).
  - 좌표 변환: `FinVectorEditor._to_pixel/_to_norm` 패턴. 세로 정규화 범위는 `RING_KEY_RANGES` 기반 고정 범위([-1.6, 1.6] 권장: `y_offset` ±0.8 + `upper/lower_height` 최대 1.4의 실용 범위를 덮되 일반 형상이 잘 보이는 스케일).
  - 그리기: 링 스테이션별 top/bottom/center 핸들(선택 링 강조), 인접 스테이션의 top끼리·bottom끼리 폴리라인으로 실루엣 윤곽, 배경 그리드 (`FinVectorEditor._draw` 스타일 재사용).
  - 입력: 핸들 드래그 → `apply_handle_drag`, 빈 윤곽 세그먼트 클릭 → `request_add_at`, 핸들 우클릭 → `request_delete`, 핸들/스테이션 클릭 → `request_select`. 드래그 시작 시 자동으로 `request_select` 선행.
  - `custom_minimum_size = Vector2(260, 150)` 수준.
- [x] **Step 3:** `-Filter BodySilhouetteEditorTest` 통과 → 커밋 `"Add body silhouette editor control (side view)"`

### Task 2: BodyEditorPanel 통합

**Files:** `scripts/ui/BodyEditorPanel.gd`, `scripts/tools/BodyEditorPanelTest.gd`

- [x] **Step 1: 실패하는 테스트.** `BodyEditorPanelTest.gd`에 추가:
  - 패널 생성 후 `panel.silhouette_editor != null`이고 패널의 첫 번째 컨트롤 영역에 존재.
  - `panel.silhouette_editor.ring_value_changed`를 수동 emit(`"mid_body", "upper_height", 0.6`)하면 rings의 해당 값이 0.6이 되고 `parameters_changed` 1회 emit.
  - `ring_add_requested(0.5)` emit 시 링이 하나 늘고 x≈0.5 위치에 삽입, `ring_delete_requested` emit 시 `MIN_RING_COUNT` 위에서만 삭제됨.
  - 슬라이더로 `upper_height` 변경 시 에디터의 `handle_norm_position`이 따라 갱신됨(역방향 동기화).
- [x] **Step 2: 구현.**
  - `_ready` 최상단(타이틀 아래)에 에디터 추가. 시그널 연결: `ring_value_changed` → (해당 링 선택 보장 후) `set_ring_parameter(key, value)`; `ring_pick_requested` → `select_ring_by_id`; `ring_add_requested(x)` → `add_ring_after_selected` 변형 — x 지정 삽입을 위해 기존 메서드를 `add_ring_at_x(x: float)`로 일반화(기존 버튼은 이를 호출); `ring_delete_requested` → 대상 링 선택 후 `delete_selected_ring`.
  - `_refresh_controls`에서 `silhouette_editor.set_rings(...)` + `selected_ring_id` 동기화. `_updating` 가드로 루프 차단.
  - 주의: `ring_value_changed`가 드래그 중 연속 emit되므로 `set_ring_parameter` → `_emit_and_refresh` → `set_rings` 재진입이 일어난다. 에디터는 드래그 중 `set_rings`를 받아도 드래그 상태(잡고 있는 핸들)를 유지해야 한다 — 드래그 중에는 rings 사본 갱신만 하고 핸들 인덱스는 ring_id로 추적.
- [x] **Step 3:** `-Filter BodyEditorPanelTest`, `-Filter BodyEditorModelTest`, `-Filter EditorApplyCoalescingTest` 통과 → 커밋 `"Embed silhouette editor in body panel"`

### Task 3: 폭 뷰 (상/하 반원 폭)

**Files:** `scripts/ui/BodySilhouetteEditor.gd`, `scripts/ui/BodyEditorPanel.gd`, `scripts/ui/UiText.gd`, 테스트 2종

- [x] **Step 1: 실패하는 테스트.** `BodySilhouetteEditorTest.gd`에 추가:
  - `editor.view_mode = "width"`에서 `handle_norm_position("mid_body", "top_width")`가 (`x`, `+top_width`), `"bottom_width"`가 (`x`, `-bottom_width`) 반환.
  - `apply_handle_drag(..., "top_width", Vector2(0, 0.1))` → `ring_value_changed("mid_body", "top_width", ...)`만 emit. 아래쪽도 대칭 확인.
- [x] **Step 2: 구현.** view_mode `"width"`: 세로 정규화 범위 [-1.2, 1.2] (`top_width`/`bottom_width` max 1.2). 핸들은 링별 top_width/bottom_width/center(center 가로 드래그 = `x`). 패널에 뷰 전환 버튼 2개("측면"/"폭", `UiText`에 라벨 추가). 추가/삭제 인터랙션은 양 뷰 공통.
- [x] **Step 3:** 테스트 통과 → 커밋 `"Add width view for upper and lower body width editing"`

### Task 4: 썸네일 생성 도구

**Files:** `scripts/tools/OptionThumbShot.gd` + tscn, `assets/option_thumbs/`

- [x] **Step 1: 도구 작성.** `MouthShot.gd` 패턴 복제: SubViewport(128×128, 투명 배경) + 머리 클로즈업 직교 카메라. 생성 대상과 변형 파라미터:
  - `head_shape`: `HeadEditorPanel.HEAD_SHAPES` 9종 — `{"head_shape": value}`만 바꿔 렌더.
  - `mouth_type`: 5종 — 입 영역 줌, `mouth_open: 0.6`으로 차이 강조.
  - `eye_style`: 5종 — 눈 영역 줌.
  - `gill_mark`·`head_ornament`는 생성 후 식별성이 부족해 보류하고 체크인 에셋에서 제거.
  - 저장 경로 `res://assets/option_thumbs/<key>/<value>.png`, 각 샷 후 `print("THUMB_SAVED <key>/<value>")`.
- [x] **Step 2: 실행 및 체크인.** 비-headless로 실행(GPU 필요): `& <godot 실행파일> --path . res://scenes/OptionThumbShot.tscn`. 생성된 PNG 전수를 육안 확인 — 형태 차이가 식별되는지. 식별이 안 되는 카테고리는 카메라/파라미터를 조정하거나 해당 카테고리 썸네일을 보류(폴백 경로가 처리).
- [x] **Step 3: 커밋.** PNG + `.import` 파일 포함 `"Add option thumbnail shots"`

### Task 5: ThumbnailOptionGrid + HeadEditorPanel 교체

**Files:** `scripts/ui/ThumbnailOptionGrid.gd`, `scripts/ui/HeadEditorPanel.gd`, `scripts/tools/ThumbnailOptionGridTest.gd` + tscn, `scripts/tools/HeadEditorPanelTest.gd`

- [x] **Step 1: 실패하는 테스트.** `ThumbnailOptionGridTest.gd`:
  - `grid.setup("head_shape", ["rounded", "pointed"], "res://assets/option_thumbs/head_shape")` 후 자식 버튼 2개, 캡션이 `UiText.option(value)`.
  - 존재하지 않는 텍스처 경로로 setup 시 텍스트-온리 버튼으로 폴백, 오류 없음.
  - `grid.select_value("pointed")` 후 해당 버튼만 pressed; 버튼 pressed 시 `value_selected("pointed")` emit.
- [x] **Step 2: 구현.** `ThumbnailOptionGrid` (Control): GridContainer(열 3~4) + 토글 Button들(`toggle_mode`, 버튼 그룹으로 단일 선택). 각 버튼: 위 TextureRect(64×64, 텍스처 있으면) + 아래 캡션 Label. API: `setup(key, values, thumb_dir)`, `select_value(value)`, `signal value_selected(value)`.
- [x] **Step 3: 패널 교체.** `HeadEditorPanel._rebuild_controls_for_mode`에서 `head_shape`·`mouth_type`·`eye_style`을 썸네일 그리드로 교체: `value_selected` → `set_head_shape`/`set_mouth_type`/`set_option_parameter`. `_refresh_controls`는 `grid.select_value(...)`로 동기화한다. `gill_mark`·`head_ornament` 등 식별성이 부족하거나 썸네일이 보류된 enum은 드롭다운 유지.
  - `HeadEditorPanelTest.gd`가 `head_option` OptionButton을 직접 참조한다면 그리드 API 기준으로 갱신. `set_head_shape` 등 공개 setter 경유 assert는 그대로 유효.
- [x] **Step 4:** `-Filter ThumbnailOptionGridTest`, `-Filter HeadEditorPanelTest` 통과 → 커밋 `"Replace head shape dropdown with thumbnail grid"`

### Task 6: 최종 검증

- [x] 신규 테스트 2종 + `BodyEditorPanelTest`, `BodyEditorModelTest`, `HeadEditorPanelTest`, `EditorApplyCoalescingTest`, `EditorParameterSyncTest`, `PresetNormalizationTest` 개별 통과.
- [x] 전체 스위트 `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` 통과.
- [x] 수동 확인: 실루엣 에디터에서 드래그한 형상이 프리뷰 메시·슬라이더 값과 일치하는가, 프리셋 로드 시 에디터가 올바로 갱신되는가, 썸네일 그리드에서 형태 전환이 드롭다운과 동일하게 동작하는가.

## Out of Scope

- 링 단면(cross-section) 포인트 에디터 — directional sculpt 계획에서 기각된 대안 1과 동일 사유로 제외.
- 핀/꼬리 모양의 썸네일화 (FinEditorPanel은 이미 `FinVectorEditor`로 직접 조작 가능).
- 썸네일의 빌드 자동 재생성 파이프라인 — 수동 1회 도구로 충분.

## Self-Review

- 에디터가 패널 변이 메서드만 경유해 emit 경로가 한 갈래로 유지됨.
- 마우스 합성 없이 테스트 가능한 공개 조작 API 설계를 강제함.
- 드래그 중 `set_rings` 재진입 문제를 사전에 명시함.
- 썸네일 부재 시 폴백으로 기능 차단이 없음.
