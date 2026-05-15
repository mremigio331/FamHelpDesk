from typing import List, Dict, Any
from datetime import datetime, timezone
import calendar
from aws_lambda_powertools import Logger

from models.embolec_balance import EmbolecBalanceModel
from models.embolec_transaction import EmbolecTransactionModel, TransactionType
from models.grab_request import GrabRequestModel
from models.grab_request_item import GrabRequestItemModel
from helpers.grab_review_helper import GrabReviewHelper


class GrabLeaderboardHelper:
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
        self.stage = stage
        self.table_name = table_name
        self.notification_queue_url = notification_queue_url
        EmbolecBalanceModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        EmbolecTransactionModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        GrabRequestModel.set_stage_and_table(stage, table_name, notification_queue_url)

    def get_leaderboard(self, family_id: str) -> Dict[str, Any]:
        """
        Queries all balances, counts confirmed requests per claimer,
        aggregates current-month earnings from transactions, retrieves
        average review ratings, and returns a leaderboard sorted by
        total_earned descending.

        Args:
            family_id: The family ID

        Returns:
            dict with "leaderboard" key containing a list of entries sorted
            by total_earned descending. Each entry has: user_id, total_earned,
            total_spent, current_balance, fulfillment_count, monthly_earnings,
            average_rating, total_review_count.
        """
        # Step 1: Query all EmbolecBalance records for the family
        balances = self._get_all_balances(family_id)

        # Step 2: Count confirmed requests per claimer
        fulfillment_counts = self._get_fulfillment_counts(family_id)

        # Step 3: Aggregate current-month GRAB_PAYMENT earnings per user
        monthly_earnings = self._get_monthly_earnings(family_id)

        # Step 4: Get average ratings for all users in the family
        review_helper = GrabReviewHelper(
            stage=self.stage,
            table_name=self.table_name,
            notification_queue_url=self.notification_queue_url,
        )
        average_ratings = review_helper.get_average_ratings_for_family(family_id)

        # Step 5: Merge data into leaderboard entries
        leaderboard = []
        for balance in balances:
            user_id = balance["user_id"]
            rating_data = average_ratings.get(user_id)
            if rating_data:
                average_rating = rating_data[0]
                total_review_count = rating_data[1]
            else:
                average_rating = None
                total_review_count = 0
            entry = {
                "user_id": user_id,
                "total_earned": balance["total_earned"],
                "total_spent": balance["total_spent"],
                "current_balance": balance["balance"],
                "fulfillment_count": fulfillment_counts.get(user_id, 0),
                "monthly_earnings": monthly_earnings.get(user_id, 0),
                "average_rating": average_rating,
                "total_review_count": total_review_count,
            }
            leaderboard.append(entry)

        # Step 6: Sort by total_earned descending
        leaderboard.sort(key=lambda x: x["total_earned"], reverse=True)

        self.logger.info(
            f"Generated leaderboard for family {family_id} with {len(leaderboard)} entries"
        )

        return {"leaderboard": leaderboard}

    def _get_all_balances(self, family_id: str) -> List[Dict[str, Any]]:
        """
        Query all EmbolecBalance records for the family.

        Args:
            family_id: The family ID

        Returns:
            List of cleaned balance dicts
        """
        results = []
        query_result = EmbolecBalanceModel.query(
            hash_key=EmbolecBalanceModel.create_pk(family_id),
            range_key_condition=EmbolecBalanceModel.sk.startswith("EMBOLEC_BALANCE#"),
        )
        for item in query_result:
            results.append(EmbolecBalanceModel.clean_returned_balance(item))

        return results

    def _get_fulfillment_counts(self, family_id: str) -> Dict[str, int]:
        """
        Count confirmed items per claimer_id.

        Args:
            family_id: The family ID

        Returns:
            Dict mapping user_id to their count of confirmed items as claimer
        """
        counts: Dict[str, int] = {}
        query_result = GrabRequestItemModel.query(
            hash_key=GrabRequestItemModel.create_pk(family_id),
            range_key_condition=GrabRequestItemModel.sk.startswith("GRAB_REQUEST#"),
        )
        for item in query_result:
            if (
                getattr(item, "status", None) == "CONFIRMED"
                and getattr(item, "claimer_id", None) is not None
            ):
                counts[item.claimer_id] = counts.get(item.claimer_id, 0) + 1

        return counts

    def _get_monthly_earnings(self, family_id: str) -> Dict[str, int]:
        """
        Sum GRAB_PAYMENT transaction amounts per to_user_id for the current
        calendar month.

        Args:
            family_id: The family ID

        Returns:
            Dict mapping user_id to their total GRAB_PAYMENT earnings this month
        """
        # Determine current month boundaries (epoch timestamps)
        now = datetime.now(timezone.utc)
        month_start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
        month_start_epoch = int(month_start.timestamp())

        # End of month
        last_day = calendar.monthrange(now.year, now.month)[1]
        month_end = datetime(
            now.year, now.month, last_day, 23, 59, 59, tzinfo=timezone.utc
        )
        month_end_epoch = int(month_end.timestamp())

        earnings: Dict[str, int] = {}
        query_result = EmbolecTransactionModel.query(
            hash_key=EmbolecTransactionModel.create_pk(family_id),
            range_key_condition=EmbolecTransactionModel.sk.startswith("EMBOLEC_TXN#"),
        )
        for item in query_result:
            if (
                item.transaction_type == TransactionType.GRAB_PAYMENT.value
                and item.created_at >= month_start_epoch
                and item.created_at <= month_end_epoch
            ):
                user_id = item.to_user_id
                earnings[user_id] = earnings.get(user_id, 0) + float(item.amount)

        return earnings
