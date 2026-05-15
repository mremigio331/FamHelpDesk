from typing import Optional, Dict, Any
from datetime import datetime
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.embolec_balance import EmbolecBalanceModel
from models.embolec_transaction import EmbolecTransactionModel, TransactionType
from models.base import FamHelpDeskBaseModel


class EmbolecHelper:
    MONTHLY_REFRESH_AMOUNT = 50

    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        EmbolecBalanceModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        EmbolecTransactionModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )

    def get_or_create_balance(self, family_id: str, user_id: str) -> dict:
        """
        Returns the user's Embolec balance for the given family.
        Creates a new balance with 50 Embolecs if this is the user's first access.
        Performs a lazy monthly refresh if the current calendar month differs
        from the month of last_refresh_date.

        Args:
            family_id: The family ID
            user_id: The user ID

        Returns:
            dict: Cleaned balance data
        """
        try:
            balance = EmbolecBalanceModel.get(
                hash_key=EmbolecBalanceModel.create_pk(family_id),
                range_key=EmbolecBalanceModel.create_sk(user_id),
            )
            self.logger.info(
                f"Found existing balance for user {user_id} in family {family_id}"
            )

            # Check if monthly refresh is needed
            if self._needs_monthly_refresh(balance.last_refresh_date):
                self._perform_monthly_refresh(balance)

            return EmbolecBalanceModel.clean_returned_balance(balance)

        except DoesNotExist:
            self.logger.info(
                f"Creating new balance for user {user_id} in family {family_id}"
            )
            return self._create_initial_balance(family_id, user_id)

    def _needs_monthly_refresh(self, last_refresh_date: int) -> bool:
        """
        Determines if a monthly refresh is needed by comparing the calendar month
        of last_refresh_date with the current calendar month.

        Args:
            last_refresh_date: Epoch timestamp of the last refresh

        Returns:
            bool: True if refresh is needed
        """
        last_refresh_dt = datetime.utcfromtimestamp(last_refresh_date)
        now_dt = datetime.utcfromtimestamp(FamHelpDeskBaseModel.now_epoch())

        return (
            last_refresh_dt.year != now_dt.year or last_refresh_dt.month != now_dt.month
        )

    def _create_initial_balance(self, family_id: str, user_id: str) -> dict:
        """
        Creates a new balance record with 50 Embolecs and a MONTHLY_REFRESH transaction.

        Args:
            family_id: The family ID
            user_id: The user ID

        Returns:
            dict: Cleaned balance data
        """
        now = FamHelpDeskBaseModel.now_epoch()

        balance = EmbolecBalanceModel(
            pk=EmbolecBalanceModel.create_pk(family_id),
            sk=EmbolecBalanceModel.create_sk(user_id),
            family_id=family_id,
            user_id=user_id,
            balance=self.MONTHLY_REFRESH_AMOUNT,
            last_refresh_date=now,
            total_earned=0,
            total_spent=0,
        )
        balance.save()

        # Create the initial MONTHLY_REFRESH transaction
        transaction_id = FamHelpDeskBaseModel.generate_random_id()
        transaction = EmbolecTransactionModel(
            pk=EmbolecTransactionModel.create_pk(family_id),
            sk=EmbolecTransactionModel.create_sk(transaction_id),
            transaction_id=transaction_id,
            family_id=family_id,
            from_user_id="SYSTEM",
            to_user_id=user_id,
            amount=self.MONTHLY_REFRESH_AMOUNT,
            transaction_type=TransactionType.MONTHLY_REFRESH.value,
            created_at=now,
        )
        transaction.save()

        self.logger.info(
            f"Created initial balance of {self.MONTHLY_REFRESH_AMOUNT} for user {user_id} in family {family_id}"
        )

        return EmbolecBalanceModel.clean_returned_balance(balance)

    def _perform_monthly_refresh(self, balance: EmbolecBalanceModel) -> None:
        """
        Adds 50 Embolecs to the balance, updates last_refresh_date to now,
        and creates a MONTHLY_REFRESH transaction.

        Args:
            balance: The EmbolecBalanceModel instance to refresh
        """
        now = FamHelpDeskBaseModel.now_epoch()

        balance.balance += self.MONTHLY_REFRESH_AMOUNT
        balance.last_refresh_date = now
        balance.save()

        # Create MONTHLY_REFRESH transaction
        transaction_id = FamHelpDeskBaseModel.generate_random_id()
        transaction = EmbolecTransactionModel(
            pk=EmbolecTransactionModel.create_pk(balance.family_id),
            sk=EmbolecTransactionModel.create_sk(transaction_id),
            transaction_id=transaction_id,
            family_id=balance.family_id,
            from_user_id="SYSTEM",
            to_user_id=balance.user_id,
            amount=self.MONTHLY_REFRESH_AMOUNT,
            transaction_type=TransactionType.MONTHLY_REFRESH.value,
            created_at=now,
        )
        transaction.save()

        self.logger.info(
            f"Monthly refresh: added {self.MONTHLY_REFRESH_AMOUNT} Embolecs for user {balance.user_id} in family {balance.family_id}"
        )

    def transfer_embolecs(
        self,
        family_id: str,
        from_user_id: str,
        to_user_id: str,
        amount: float,
        grab_request_id: str,
        item_id: str = None,
    ) -> dict:
        """
        Transfers Embolecs from one user to another. Deducts from sender,
        adds to receiver, updates total_spent/total_earned, and creates
        a GRAB_PAYMENT transaction.

        Negative balances are allowed (no balance check).

        Args:
            family_id: The family ID
            from_user_id: The sender's user ID
            to_user_id: The receiver's user ID
            amount: The amount to transfer
            grab_request_id: The associated Grab Request ID

        Returns:
            dict: The created transaction as a cleaned dict
        """
        now = FamHelpDeskBaseModel.now_epoch()

        # Deduct from sender
        try:
            sender_balance = EmbolecBalanceModel.get(
                hash_key=EmbolecBalanceModel.create_pk(family_id),
                range_key=EmbolecBalanceModel.create_sk(from_user_id),
            )
        except DoesNotExist:
            # If sender has no balance yet, create one first (with monthly refresh)
            self.get_or_create_balance(family_id, from_user_id)
            sender_balance = EmbolecBalanceModel.get(
                hash_key=EmbolecBalanceModel.create_pk(family_id),
                range_key=EmbolecBalanceModel.create_sk(from_user_id),
            )

        sender_balance.balance -= amount
        sender_balance.total_spent += amount
        sender_balance.save()

        # Add to receiver
        try:
            receiver_balance = EmbolecBalanceModel.get(
                hash_key=EmbolecBalanceModel.create_pk(family_id),
                range_key=EmbolecBalanceModel.create_sk(to_user_id),
            )
        except DoesNotExist:
            # If receiver has no balance yet, create one first (with monthly refresh)
            self.get_or_create_balance(family_id, to_user_id)
            receiver_balance = EmbolecBalanceModel.get(
                hash_key=EmbolecBalanceModel.create_pk(family_id),
                range_key=EmbolecBalanceModel.create_sk(to_user_id),
            )

        receiver_balance.balance += amount
        receiver_balance.total_earned += amount
        receiver_balance.save()

        # Create GRAB_PAYMENT transaction
        transaction_id = FamHelpDeskBaseModel.generate_random_id()
        transaction = EmbolecTransactionModel(
            pk=EmbolecTransactionModel.create_pk(family_id),
            sk=EmbolecTransactionModel.create_sk(transaction_id),
            transaction_id=transaction_id,
            family_id=family_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            amount=amount,
            transaction_type=TransactionType.GRAB_PAYMENT.value,
            grab_request_id=grab_request_id,
            created_at=now,
        )
        if item_id:
            transaction.item_id = item_id
        transaction.save()

        self.logger.info(
            f"Transferred {amount} Embolecs from {from_user_id} to {to_user_id} "
            f"for grab request {grab_request_id} in family {family_id}"
        )

        return EmbolecTransactionModel.clean_returned_transaction(transaction)

    def get_transactions(
        self,
        family_id: str,
        limit: int = 20,
        last_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Returns a paginated list of transactions for a family, sorted by
        newest first.

        Args:
            family_id: The family ID
            limit: Maximum number of transactions to return (default 20, max 50)
            last_key: DynamoDB last_evaluated_key for pagination

        Returns:
            dict with:
                - transactions: list of cleaned transaction dicts
                - last_key: pagination key or None
        """
        # Enforce max limit
        if limit > 50:
            limit = 50

        query_kwargs = {
            "hash_key": EmbolecTransactionModel.create_pk(family_id),
            "range_key_condition": EmbolecTransactionModel.sk.startswith(
                "EMBOLEC_TXN#"
            ),
            "scan_index_forward": False,
            "limit": limit,
        }

        if last_key:
            query_kwargs["last_evaluated_key"] = last_key

        result_page = EmbolecTransactionModel.query(**query_kwargs)

        transactions = []
        for item in result_page:
            transactions.append(
                EmbolecTransactionModel.clean_returned_transaction(item)
            )

        # Get pagination key
        next_key = None
        if (
            hasattr(result_page, "last_evaluated_key")
            and result_page.last_evaluated_key
        ):
            next_key = result_page.last_evaluated_key

        self.logger.info(
            f"Retrieved {len(transactions)} transactions for family {family_id}, "
            f"limit: {limit}, has_next_key: {next_key is not None}"
        )

        return {
            "transactions": transactions,
            "last_key": next_key,
        }
