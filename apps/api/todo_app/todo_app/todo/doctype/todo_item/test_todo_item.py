# Copyright (c) 2026, Todo App and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from todo_app.api import me, stats
from todo_app.install import TODO_ROLE, ensure_todo_role

EXTRA_TEST_RECORD_DEPENDENCIES = []
IGNORE_TEST_RECORD_DEPENDENCIES = []


def make_user(email: str) -> str:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{
				"doctype": "User",
				"email": email,
				"first_name": email.split("@")[0],
				"send_welcome_email": 0,
				"roles": [{"role": TODO_ROLE}],
			}
		).insert(ignore_permissions=True)
	return email


class IntegrationTestTodoItem(IntegrationTestCase):
	"""Rules of the Todo Item DocType: defaults, derived fields, per-user isolation, API helpers."""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		ensure_todo_role()
		cls.alice = make_user("alice.todo@example.com")
		cls.bob = make_user("bob.todo@example.com")

	def tearDown(self):
		frappe.set_user("Administrator")

	def new_todo(self, **values):
		return frappe.get_doc({"doctype": "Todo Item", "title": "Write tests", **values}).insert()

	def test_defaults_and_naming(self):
		todo = self.new_todo()
		self.assertTrue(todo.name.startswith("TODO-"))
		self.assertEqual(todo.status, "Open")
		self.assertEqual(todo.priority, "Medium")
		self.assertIsNone(todo.completed_at)

	def test_title_is_trimmed_and_cannot_be_blank(self):
		self.assertEqual(self.new_todo(title="  buy milk  ").title, "buy milk")
		with self.assertRaises(frappe.ValidationError):
			self.new_todo(title="   ")

	def test_completed_at_follows_status(self):
		todo = self.new_todo()

		todo.status = "Done"
		todo.save()
		stamped = todo.completed_at
		self.assertIsNotNone(stamped)

		todo.title = "Renamed"
		todo.save()
		self.assertEqual(todo.completed_at, stamped)

		todo.status = "Open"
		todo.save()
		self.assertIsNone(todo.completed_at)

	def test_users_only_see_their_own_todos(self):
		frappe.set_user(self.alice)
		todo = self.new_todo(title="Alice's todo")
		self.assertTrue(frappe.has_permission("Todo Item", "write", doc=todo))

		frappe.set_user(self.bob)
		self.assertNotIn(todo.name, frappe.get_list("Todo Item", pluck="name"))
		self.assertFalse(frappe.has_permission("Todo Item", "read", doc=todo))
		self.assertFalse(frappe.has_permission("Todo Item", "delete", doc=todo))

	def test_stats_counts_only_my_todos(self):
		frappe.set_user(self.alice)
		self.new_todo()
		self.new_todo(status="Done")

		frappe.set_user(self.bob)
		self.new_todo(status="In Progress")

		frappe.set_user(self.alice)
		self.assertEqual(stats(), {"Open": 1, "In Progress": 0, "Done": 1, "total": 2})

	def test_me(self):
		frappe.set_user("Guest")
		self.assertIsNone(me())

		frappe.set_user(self.alice)
		self.assertEqual(me()["user"], self.alice)
