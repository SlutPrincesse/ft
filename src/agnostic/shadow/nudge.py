"""Shadow nudge - native monitor for hung processes."""

import logging
import time
from datetime import datetime, timedelta
from typing import Any, Dict, Optional

from ..config import HarnessConfig


class ShadowNudge:
    """
    Native shadow-nudge: monitors I/O data flows and tool execution timing.
    
    Automatically interrupts and nudges LLM to pivot on hung processes.
    """
    
    def __init__(self, timeout_seconds: int = 600):
        self.timeout = timeout_seconds
        self.last_activity = datetime.utcnow()
        self.logger = logging.getLogger("agnostic.shadow.nudge")
    
    def update_activity(self):
        """Update last activity timestamp."""
        self.last_activity = datetime.utcnow()
    
    def check_hung(self) -> bool:
        """Check if execution has hung."""
        elapsed = (datetime.utcnow() - self.last_activity).total_seconds()
        return elapsed >= self.timeout
    
    def nudge(self) -> Dict[str, Any]:
        """Trigger a nudge to the LLM."""
        self.logger.warning("[SHADOW-NUDGE] Tool execution hung (>10m zero I/O)")
        return {
            "action": "abort",
            "reason": "hung_process",
            "elapsed_seconds": (datetime.utcnow() - self.last_activity).total_seconds(),
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Get current nudge status."""
        elapsed = (datetime.utcnow() - self.last_activity).total_seconds()
        return {
            "last_activity": self.last_activity.isoformat(),
            "elapsed_seconds": elapsed,
            "is_hung": elapsed >= self.timeout,
            "timeout_seconds": self.timeout,
        }
