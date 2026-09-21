# Copyright (c) 2026, Todo App and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import now_datetime


class TodoItem(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		completed_at: DF.Datetime | None
		description: DF.SmallText | None
		due_date: DF.Date | None
		priority: DF.Literal["Low", "Medium", "High"]
		status: DF.Literal["Open", "In Progress", "Done"]
		title: DF.Data
	# end: auto-generated types

	def validate(self):
		self.title = (self.title or "").strip()
		if not self.title:
			frappe.throw(_("Title cannot be empty."))

		self.sync_completed_at()

	def sync_completed_at(self):
		"""completed_at is derived from status, never taken from the client.

		Stamped when the item becomes Done, cleared when it is reopened, untouched otherwise.
		"""
		if self.status != "Done":
			self.completed_at = None
		elif self.is_new() or self.has_value_changed("status"):
			self.completed_at = now_datetime()
		else:
			self.completed_at = self.get_db_value("completed_at")
