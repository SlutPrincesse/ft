#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - TUI Interface
Terminal User Interface for interactive harness operations.
"""

import sys
from pathlib import Path
from typing import Optional, Dict, Any, List
import logging

sys.path.insert(0, str(Path(__file__).parent))

from harness_core import HarnessOrchestrator, TaskDAG, Task
from harness_modules import AGNOSTIC_HARVESTER, LEDv3LinguisticEngine
from shadow_broker import ShadowBroker
from shadow_agent import ShadowFS, ShadowNudge


class HarnessTUI:
    """
    Terminal User Interface for the AGNOSTIC-HARVESTER Harness.
    
    Features:
    - Slash commands for all operations
    - Keyboard shortcuts
    - Interactive disambiguation menus
    - Real-time task DAG visualization
    """
    
    def __init__(self):
        self.orchestrator = HarnessOrchestrator()
        self.harness = AGNOSTIC_HARVESTER()
        self.led = LEDv3LinguisticEngine()
        self.broker = ShadowBroker()
        self.shadow_fs = ShadowFS()
        self.nudge = ShadowNudge()
        
        self.running = False
        self.current_mode = "ocd"
        self.neuro_modes = ["ocd", "adhd", "autistic", "bipolar", "schizophrenia", "shadow-clones"]
        
        self.logger = logging.getLogger("harness.tui")
    
    def start(self):
        """Start the TUI main loop."""
        self.orchestrator.initialize()
        self.running = True
        
        print("=" * 70)
        print("  AGNOSTIC-HARVESTER Harness v1.0.0")
        print("  Type /help for commands, Ctrl+C to exit")
        print("=" * 70)
        
        while self.running:
            try:
                user_input = input("\nharness> ").strip()
                
                if not user_input:
                    continue
                
                # Handle slash commands
                if user_input.startswith("/"):
                    self._handle_command(user_input)
                else:
                    # Process as prompt
                    self._process_prompt(user_input)
                    
            except KeyboardInterrupt:
                print("\nExiting...")
                self.running = False
                break
            except EOFError:
                print("\nExiting...")
                self.running = False
                break
    
    def _handle_command(self, command: str):
        """Handle slash commands."""
        parts = command.split()
        cmd = parts[0].lower()
        args = parts[1:] if len(parts) > 1 else []
        
        commands = {
            "/help": self._cmd_help,
            "/menu": self._cmd_menu,
            "/mode": self._cmd_mode,
            "/task": self._cmd_task,
            "/research": self._cmd_research,
            "/install": self._cmd_install,
            "/nudge": self._cmd_nudge,
            "/compact": self._cmd_compact,
            "/stealth": self._cmd_stealth,
            "/audit": self._cmd_audit,
            "/weather": self._cmd_weather,
            "/fs": self._cmd_fs,
            "/plan": self._cmd_plan,
            "/skills": self._cmd_skills,
            "/status": self._cmd_status,
            "/exit": self._cmd_exit,
            "/quit": self._cmd_exit,
        }
        
        handler = commands.get(cmd)
        if handler:
            handler(args)
        else:
            print(f"Unknown command: {cmd}. Type /help for available commands.")
    
    def _cmd_help(self, args: List[str]):
        """Show help."""
        help_text = """
Available Commands:
  /help                    Show this help message
  /menu                    Open interactive operations hub
  /mode <mode>             Switch neuro-mode (ocd, adhd, autistic, bipolar, schizophrenia, shadow-clones)
  /task [add|list|pop|clear]  Manage task DAG
  /research <query>        Shadow Broker GitHub research
  /install <crate|repo>    Install Rust single-binary tool globally
  /nudge                   Manual shadow-nudge diagnostic
  /compact                 Force context compaction
  /stealth [on|off]        Toggle shadow-browser stealth
  /audit                   Run comprehensive codebase audit
  /weather                 Update TUI weather theme
  /fs shadow               Open shadow-fs file browser
  /plan show               Display current tool creation plan
  /skills list             Show all registered tools
  /status                  Show harness status
  /exit /quit              Graceful exit
        """
        print(help_text)
    
    def _cmd_menu(self, args: List[str]):
        """Open interactive operations hub."""
        print("\n" + "=" * 50)
        print("  OPERATIONS HUB")
        print("=" * 50)
        print("  1. Process Prompt")
        print("  2. Shadow Broker Research")
        print("  3. View Task DAG")
        print("  4. Run Audit")
        print("  5. Toggle Stealth")
        print("  6. Switch Neuro-Mode")
        print("  0. Exit")
        print("=" * 50)
        
        try:
            choice = input("Select option: ").strip()
            if choice == "1":
                prompt = input("Enter prompt: ").strip()
                self._process_prompt(prompt)
            elif choice == "2":
                query = input("Enter research query: ").strip()
                self._cmd_research([query])
            elif choice == "3":
                self._cmd_task(["list"])
            elif choice == "4":
                self._cmd_audit([])
            elif choice == "5":
                self._cmd_stealth(["toggle"])
            elif choice == "6":
                self._show_neuro_mode_selector()
            elif choice == "0":
                self.running = False
        except (KeyboardInterrupt, EOFError):
            pass
    
    def _show_neuro_mode_selector(self):
        """Show neuro-mode selector."""
        print("\nAvailable Neuro-Modes:")
        for idx, mode in enumerate(self.neuro_modes, 1):
            marker = " [ACTIVE]" if mode == self.current_mode else ""
            print(f"  {idx}. {mode}{marker}")
        
        try:
            choice = input("Select mode (number): ").strip()
            if choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(self.neuro_modes):
                    self.current_mode = self.neuro_modes[idx]
                    print(f"Switched to mode: {self.current_mode}")
        except (KeyboardInterrupt, EOFError):
            pass
    
    def _cmd_mode(self, args: List[str]):
        """Switch neuro-mode."""
        if not args:
            print(f"Current mode: {self.current_mode}")
            print(f"Available: {', '.join(self.neuro_modes)}")
            return
        
        mode = args[0].lower()
        if mode in self.neuro_modes:
            self.current_mode = mode
            print(f"Switched to mode: {mode}")
        else:
            print(f"Unknown mode: {mode}")
    
    def _cmd_task(self, args: List[str]):
        """Manage task DAG."""
        if not args:
            args = ["list"]
        
        action = args[0].lower()
        
        if action == "list":
            status = self.orchestrator.get_status()
            dag = status.get("dag", {})
            tasks = dag.get("tasks", {})
            
            print(f"\nTask DAG ({len(tasks)} tasks):")
            print("-" * 60)
            for task_id, task in tasks.items():
                status_marker = {
                    "pending": "○",
                    "locked": "◐",
                    "running": "◉",
                    "completed": "●",
                    "failed": "✗",
                    "yielded": "~",
                }.get(task["status"], "?")
                
                desc = task["description"][:50]
                print(f"  {status_marker} [{task_id}] {desc}")
            print("-" * 60)
        
        elif action == "add":
            if len(args) < 2:
                print("Usage: /task add <description>")
                return
            description = " ".join(args[1:])
            task = self.orchestrator.dag.add_task(description)
            self.orchestrator.dag.save()
            print(f"Added task: {task.id}")
        
        elif action == "pop":
            next_task = self.orchestrator.dag.get_next_ready_task()
            if next_task:
                print(f"Next task: {next_task.id} - {next_task.description}")
            else:
                print("No ready tasks")
        
        elif action == "clear":
            self.orchestrator.dag.tasks.clear()
            self.orchestrator.dag.save()
            print("Task DAG cleared")
        
        else:
            print(f"Unknown task action: {action}")
    
    def _cmd_research(self, args: List[str]):
        """Shadow Broker research."""
        if not args:
            print("Usage: /research <query>")
            return
        
        query = " ".join(args)
        print(f"Shadow Broker researching: {query}")
        
        result = self.broker.research_and_plan(query)
        
        if result.get("status") == "no_results":
            print("No results found")
            return
        
        print(f"\nFound {len(result.get('candidates', []))} candidates:")
        for idx, candidate in enumerate(result.get("candidates", [])[:5], 1):
            print(f"  {idx}. {candidate['name']} (★{candidate.get('relevance_score', 0):.2f})")
            print(f"     {candidate.get('description', 'No description')[:80]}")
        
        if result.get("plans"):
            print(f"\n{len(result['plans'])} tool creation plans pending human approval")
    
    def _cmd_install(self, args: List[str]):
        """Install Rust single-binary tool globally."""
        if not args:
            print("Usage: /install <crate|repo>")
            return
        
        target = args[0]
        print(f"Installing: {target}")
        
        # Placeholder for cargo install
        print(f"[PLACEHOLDER] Would install {target} globally via cargo install")
    
    def _cmd_nudge(self, args: List[str]):
        """Manual shadow-nudge diagnostic."""
        result = self.nudge.nudge()
        print(f"Shadow Nudge: {result}")
    
    def _cmd_compact(self, args: List[str]):
        """Force context compaction."""
        print("Compacting context...")
        self.orchestrator.shadow_git.compact()
        print("Compaction complete")
    
    def _cmd_stealth(self, args: List[str]):
        """Toggle stealth mode."""
        if not args or args[0] == "toggle":
            current = self.orchestrator.state.state.get("stealth_enabled", False)
            new_state = not current
            self.orchestrator.state.state["stealth_enabled"] = new_state
            self.orchestrator.state.save()
            print(f"Stealth mode: {'ON' if new_state else 'OFF'}")
        else:
            state = args[0].lower() in ("on", "true", "1")
            self.orchestrator.state.state["stealth_enabled"] = state
            self.orchestrator.state.save()
            print(f"Stealth mode: {'ON' if state else 'OFF'}")
    
    def _cmd_audit(self, args: List[str]):
        """Run comprehensive audit."""
        print("Running audit...")
        from harness_modules import PostQueueAuditor
        auditor = PostQueueAuditor()
        report = auditor.audit(self.orchestrator.dag)
        
        print(f"\nAudit Report:")
        print(f"  Total tasks: {report['total_tasks']}")
        print(f"  Completed: {report['completed']}")
        print(f"  Failed: {report['failed']}")
        print(f"  Yielded: {report['yielded']}")
        print(f"\nRecommendations:")
        for rec in report.get("recommendations", []):
            print(f"  - {rec['description']} [{rec['priority']}]")
    
    def _cmd_weather(self, args: List[str]):
        """Update weather theme."""
        print("Weather theme update: [PLACEHOLDER - would fetch wttr.in]")
    
    def _cmd_fs(self, args: List[str]):
        """Open shadow-fs file browser."""
        if not args or args[0] != "shadow":
            print("Usage: /fs shadow")
            return
        
        worktrees = self.shadow_fs.list_worktrees()
        print(f"\nShadow Worktrees ({len(worktrees)}):")
        for wt in worktrees:
            print(f"  {wt}")
    
    def _cmd_plan(self, args: List[str]):
        """Display current tool creation plan."""
        if not args or args[0] != "show":
            print("Usage: /plan show")
            return
        
        print("Tool Creation Plans:")
        print("  [PLACEHOLDER - would show pending plans]")
    
    def _cmd_skills(self, args: List[str]):
        """Show registered tools."""
        if not args or args[0] != "list":
            print("Usage: /skills list")
            return
        
        tools = self.orchestrator.tools.list_tools()
        print(f"\nRegistered Tools ({len(tools)}):")
        for tool in tools:
            print(f"  - {tool['name']} ({tool.get('version', 'unknown')})")
            if tool.get('source_repo'):
                print(f"    Source: {tool['source_repo']}")
    
    def _cmd_status(self, args: List[str]):
        """Show harness status."""
        status = self.orchestrator.get_status()
        
        print(f"\nHarness Status:")
        print(f"  Active Mode: {status['state'].get('active_mode', 'unknown')}")
        print(f"  Tasks: {len(status['dag'].get('tasks', {}))}")
        print(f"  Tools: {len(status.get('tools', []))}")
        print(f"  Shadow Deltas: {status.get('shadow_deltas_count', 0)}")
    
    def _cmd_exit(self, args: List[str]):
        """Graceful exit."""
        print("Shutting down harness...")
        self.orchestrator.shadow_git.compact()
        print("Memory compacted. Goodbye!")
        self.running = False
    
    def _process_prompt(self, prompt: str):
        """Process a prompt through the harness pipeline."""
        print(f"\n[LED v3.0] Processing prompt...")
        
        # LED v3.0 processing
        profile = self.led.process(prompt)
        
        if profile.corrections:
            print(f"  Corrections: {len(profile.corrections)}")
            for corr in profile.corrections:
                print(f"    - {corr['original']} -> {corr['corrected']}")
        
        if profile.ambiguities:
            print(f"  Ambiguities detected: {len(profile.ambiguities)}")
            for amb in profile.ambiguities:
                print(f"    - '{amb.term}': {amb.suggestions}")
        
        print(f"\n[Harness] Running pipeline...")
        result = self.harness.process_prompt(profile.normalized)
        
        print(f"  Status: {result['status']}")
        print(f"  Tasks processed: {result['tasks_processed']}")
        
        if result.get("audit"):
            audit = result["audit"]
            print(f"  Audit: {audit['completed']}/{audit['total_tasks']} passed")


def main():
    """Main entry point for the TUI."""
    import logging
    
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    
    tui = HarnessTUI()
    tui.start()


if __name__ == "__main__":
    main()
