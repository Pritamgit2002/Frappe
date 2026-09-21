"""Custom REST methods, served at /api/method/todo_app.api.<name>.

Plain CRUD needs no code here: Frappe already serves /api/resource/Todo Item.
"""

import frappe
from frappe.utils import get_fullname

TODO_DOCTYPE = "Todo Item"
STATUSES = ("Open", "In Progress", "Done")


@frappe.whitelist(allow_guest=True, methods=["GET"])
def me() -> dict | None:
	"""Return the logged-in user, or None for guests.

	Lets a frontend validate its session with one cheap call (frappe.auth.get_logged_user
	isn't open to guests, so an expired session would surface as a 403 instead of a clean "not logged in").
	"""
	user = frappe.session.user
	if user == "Guest":
		return None

	return {"user": user, "full_name": get_fullname(user)}


@frappe.whitelist(methods=["GET"])
def stats() -> dict:
	"""Todo counts per status for the current user, plus a total.

	Uses get_list, so document permissions apply. The owner filter also makes this "my todos"
	for users (like System Manager) whose role isn't restricted to their own documents.
	"""
	rows = frappe.get_list(
		TODO_DOCTYPE,
		filters={"owner": frappe.session.user},
		fields=["status", {"COUNT": "*", "as": "count"}],  # v16: SQL functions must use dict syntax
		group_by="status",
	)

	counts = dict.fromkeys(STATUSES, 0)
	for row in rows:
		counts[row.status] = row.count
	counts["total"] = sum(counts.values())
	return counts
