app_name = "todo_app"
app_title = "Todo App"
app_publisher = "Todo App"
app_description = "Todo backend (Frappe app) for the frappe-todo monorepo"
app_email = "dev@example.com"
app_license = "mit"

# Installation
# ------------

# Runs before DocTypes are synced, so the "Todo User" role already exists when the
# Todo Item permissions that reference it are imported.
before_install = "todo_app.install.before_install"
