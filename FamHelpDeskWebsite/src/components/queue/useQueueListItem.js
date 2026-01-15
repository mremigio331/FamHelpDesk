import { useCallback } from "react";
import { useNavigate } from "react-router-dom";

/**
 * Custom hook for QueueListItem logic
 * Provides default actions and handlers for queue list items
 */
export const useQueueListItem = ({ queue, actions }) => {
  const navigate = useNavigate();

  const handleView = useCallback(() => {
    if (queue?.family_id && queue?.queue_id) {
      navigate(`/family/${queue.family_id}/queue/${queue.queue_id}`);
    }
  }, [queue, navigate]);

  const defaultActions = [
    {
      key: "view",
      label: "View",
      onClick: handleView,
    },
  ];

  return {
    defaultActions,
    handleView,
  };
};

export default useQueueListItem;
