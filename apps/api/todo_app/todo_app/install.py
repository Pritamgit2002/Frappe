import os

import frappe

TODO_ROLE = "Todo User"


def before_install():
	ensure_todo_role()


def ensure_todo_role():
	"""Create the role that the Todo Item permissions refer to. Idempotent.

	desk_access=0 keeps users who only hold this role as "Website Users": they can use the REST API
	(and therefore the Next.js frontend) but cannot open the Frappe desk.
	"""
	if frappe.db.exists("Role", TODO_ROLE):
		return

	frappe.get_doc({"doctype": "Role", "role_name": TODO_ROLE, "desk_access": 0}).insert(
		ignore_permissions=True
	)


def create_demo_user():
	"""Create or refresh a demo end-user. Dev helper, run by scripts/setup.sh via `bench execute`.

	Reads DEMO_USER_EMAIL / DEMO_USER_PASSWORD / DEMO_USER_NAME from the environment so the password
	never shows up in a command line.
	"""
	email = os.environ.get("DEMO_USER_EMAIL", "").strip()
	password = os.environ.get("DEMO_USER_PASSWORD", "")
	if not (email and password):
		print("DEMO_USER_EMAIL / DEMO_USER_PASSWORD not set, skipping demo user.")
		return

	ensure_todo_role()

	if frappe.db.exists("User", email):
		user = frappe.get_doc("User", email)
	else:
		user = frappe.new_doc("User")
		user.email = email
		user.first_name = os.environ.get("DEMO_USER_NAME", "").strip() or "Demo"
		user.send_welcome_email = 0

	user.enabled = 1
	user.new_password = password
	# Dev convenience: let the demo password be whatever the developer put in .env.
	user.flags.ignore_password_policy = True
	if not any(row.role == TODO_ROLE for row in user.roles):
		user.append("roles", {"role": TODO_ROLE})

	user.save(ignore_permissions=True)
	print(f"Demo user ready: {email}")
