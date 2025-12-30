///|
/// CSS display property
pub(all) enum Display {
  Block
  Flex
  Grid
  None
} derive(Show)

///|
/// CSS position property
pub(all) enum Position {
  Relative
  Absolute
} derive(Show)

///|
/// Flex direction
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Show)

///|
/// Alignment for justify-content, align-items, etc.
pub(all) enum Alignment {
  Start
  End
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Stretch
} derive(Show)

///|
/// CSS float property (currently unsupported, for detection only)
pub(all) enum Float {
  None
  Left
  Right
} derive(Show)

///|
/// CSS Style definition for layout computation
pub(all) struct Style {
  display : Display
  position : Position
  float : Float
  // Sizing
  width : @types.Dimension
  height : @types.Dimension
  min_width : @types.Dimension
  min_height : @types.Dimension
  max_width : @types.Dimension
  max_height : @types.Dimension
  // Box model
  margin : @types.Rect[@types.Dimension]
  padding : @types.Rect[@types.Dimension]
  border : @types.Rect[@types.Dimension]
  // Flexbox
  flex_direction : FlexDirection
  justify_content : Alignment
  align_items : Alignment
  flex_grow : Double
  flex_shrink : Double
}

///|
pub fn Style::default() -> Style {
  {
    display: Block,
    position: Relative,
    float: None,
    width: @types.Auto,
    height: @types.Auto,
    min_width: @types.Auto,
    min_height: @types.Auto,
    max_width: @types.Auto,
    max_height: @types.Auto,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    border: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    flex_direction: Row,
    justify_content: Start,
    align_items: Stretch,
    flex_grow: 0.0,
    flex_shrink: 1.0,
  }
}
