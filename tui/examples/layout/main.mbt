///|
/// Layout example - demonstrates complex TUI layouts

///|
fn main {
  let (cols, rows) = @tui.get_terminal_size()
  let width = cols
  let height = rows

  // Build the complex layout
  let ui = build_dashboard(width, height)

  // Render once
  let output = @tui.render_once(width, height, ui)
  println(output)
}

///|
/// Build a dashboard-style layout
fn build_dashboard(width : Int, height : Int) -> @tui.Component {
  @c.column(
    {
      ..@c.ColumnOptions::default(),
      width: @types.Dimension::Length(width.to_double()),
      height: @types.Dimension::Length(height.to_double()),
    },
    [
      // Header
      header(),
      // Main content area
      @c.row({ ..@c.RowOptions::default(), flex_grow: 1.0 }, [
        // Sidebar
        sidebar(),
        // Main content
        main_content(),
      ]),
      // Footer
      footer(),
    ],
  )
}

///|
/// Header component
fn header() -> @tui.Component {
  @c.row(
    {
      ..@c.RowOptions::default(),
      height: @types.Dimension::Length(3.0),
      padding_x: 1.0,
      justify: @style.Alignment::SpaceBetween,
      align: @style.Alignment::Center,
      border: Some(@tui.BorderChars::single()),
      border_color: @tui.Color::cyan(),
      bg: @tui.Color::rgb(20, 20, 40),
    },
    [
      @c.bold("TUI Dashboard"),
      @c.row_gap(2.0, [
        @c.colored("Home", @tui.Color::green()),
        @c.text_("Settings"),
        @c.text_("Help"),
      ]),
    ],
  )
}

///|
/// Sidebar component
fn sidebar() -> @tui.Component {
  @c.column(
    {
      ..@c.ColumnOptions::default(),
      width: @types.Dimension::Length(20.0),
      padding: 1.0,
      gap: 1.0,
      border: Some(@tui.BorderChars::single()),
      border_color: @tui.Color::rgb(80, 80, 80),
    },
    [
      @c.bold("Navigation"),
      @c.hdivider(char='─', fg=@tui.Color::rgb(60, 60, 60)),
      menu_item("Dashboard", true),
      menu_item("Analytics", false),
      menu_item("Reports", false),
      menu_item("Users", false),
      menu_item("Settings", false),
      @c.spacer(),
      @c.colored("v1.0.0", @tui.Color::rgb(100, 100, 100)),
    ],
  )
}

///|
/// Menu item component
fn menu_item(label : String, active : Bool) -> @tui.Component {
  if active {
    @c.row(
      {
        ..@c.RowOptions::default(),
        padding_x: 1.0,
        bg: @tui.Color::rgb(40, 80, 120),
      },
      [@c.colored("▸ " + label, @tui.Color::cyan())],
    )
  } else {
    @c.row({ ..@c.RowOptions::default(), padding_x: 1.0 }, [
      @c.text_("  " + label),
    ])
  }
}

///|
/// Main content area
fn main_content() -> @tui.Component {
  @c.column(
    { ..@c.ColumnOptions::default(), flex_grow: 1.0, padding: 1.0, gap: 1.0 },
    [
      // Stats cards
      @c.row_gap(1.0, [
        stat_card("Users", "1,234", @tui.Color::green()),
        stat_card("Revenue", "$5.6K", @tui.Color::yellow()),
        stat_card("Orders", "89", @tui.Color::cyan()),
        stat_card("Growth", "+12%", @tui.Color::magenta()),
      ]),
      // Two-column layout
      @c.row({ ..@c.RowOptions::default(), flex_grow: 1.0, gap: 1.0 }, [
        // Left panel - Recent activity
        activity_panel(),
        // Right panel - Grid example
        grid_panel(),
      ]),
    ],
  )
}

///|
/// Stat card component
fn stat_card(
  title : String,
  value : String,
  color : @tui.Color,
) -> @tui.Component {
  @c.column(
    {
      ..@c.ColumnOptions::default(),
      flex_grow: 1.0,
      padding: 1.0,
      align: @style.Alignment::Center,
      border: Some(@tui.BorderChars::rounded()),
      border_color: color,
    },
    [
      @c.colored(value, color),
      @c.colored(title, @tui.Color::rgb(128, 128, 128)),
    ],
  )
}

///|
/// Activity panel
fn activity_panel() -> @tui.Component {
  @c.column(
    {
      ..@c.ColumnOptions::default(),
      flex_grow: 1.0,
      padding: 1.0,
      gap: 0.5,
      border: Some(@tui.BorderChars::single()),
      border_color: @tui.Color::rgb(60, 60, 60),
    },
    [
      @c.bold("Recent Activity"),
      @c.hdivider(char='─', fg=@tui.Color::rgb(60, 60, 60)),
      activity_item("User signed up", "2m ago", @tui.Color::green()),
      activity_item("Order completed", "5m ago", @tui.Color::cyan()),
      activity_item("Payment received", "12m ago", @tui.Color::yellow()),
      activity_item("Report generated", "1h ago", @tui.Color::magenta()),
      activity_item(
        "Settings updated",
        "2h ago",
        @tui.Color::rgb(150, 150, 150),
      ),
      @c.spacer(),
    ],
  )
}

///|
/// Activity item
fn activity_item(
  text : String,
  time : String,
  color : @tui.Color,
) -> @tui.Component {
  @c.row(
    { ..@c.RowOptions::default(), justify: @style.Alignment::SpaceBetween },
    [
      @c.row_gap(1.0, [@c.colored("●", color), @c.text_(text)]),
      @c.colored(time, @tui.Color::rgb(100, 100, 100)),
    ],
  )
}

///|
/// Grid panel demonstrating grid layout
fn grid_panel() -> @tui.Component {
  @c.column(
    {
      ..@c.ColumnOptions::default(),
      flex_grow: 1.0,
      padding: 1.0,
      border: Some(@tui.BorderChars::single()),
      border_color: @tui.Color::rgb(60, 60, 60),
    },
    [
      @c.bold("Grid Layout"),
      @c.hdivider(char='─', fg=@tui.Color::rgb(60, 60, 60)),
      @c.grid_gap(3, 1.0, [
        grid_cell("A1", @tui.Color::red()),
        grid_cell("B1", @tui.Color::green()),
        grid_cell("C1", @tui.Color::blue()),
        grid_cell("A2", @tui.Color::yellow()),
        grid_cell("B2", @tui.Color::cyan()),
        grid_cell("C2", @tui.Color::magenta()),
        grid_cell("A3", @tui.Color::rgb(255, 128, 0)),
        grid_cell("B3", @tui.Color::rgb(128, 255, 0)),
        grid_cell("C3", @tui.Color::rgb(0, 128, 255)),
      ]),
      @c.spacer(),
    ],
  )
}

///|
/// Grid cell
fn grid_cell(label : String, color : @tui.Color) -> @tui.Component {
  @c.center([@c.bordered([@c.colored(label, color)], color~)])
}

///|
/// Footer component
fn footer() -> @tui.Component {
  @c.row(
    {
      ..@c.RowOptions::default(),
      height: @types.Dimension::Length(1.0),
      padding_x: 1.0,
      justify: @style.Alignment::SpaceBetween,
      bg: @tui.Color::rgb(30, 30, 30),
    },
    [
      @c.colored("Press 'q' to quit", @tui.Color::rgb(100, 100, 100)),
      @c.colored("crater-tui v0.0.1", @tui.Color::rgb(100, 100, 100)),
    ],
  )
}
