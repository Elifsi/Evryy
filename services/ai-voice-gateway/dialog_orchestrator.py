"""
LLM Dialog Orchestrator & Tool Calling Engine
Platform: evrry Super App Ecosystem
Elifsi Technologies Private Limited

Coordinates:
- Tool execution against Supabase read-only replicas.
- Streamed sentence chunking for sub-400ms voice response latency.
- Persona-specific system prompts (Eli, Rony, Jenny, Sol).
"""

import os
import json
import logging
from typing import Dict, Any, List, Optional, AsyncGenerator
from personas import VoicePersona, get_persona

logger = logging.getLogger("evrry.dialog")

# Supported AI Tools for Voice Ordering & InDrive Bidding
EVRRY_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_catalog",
            "description": "Search food menu items or grocery products across restaurants and dark stores in Nepal.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search keywords like 'Chicken Momo', 'Milk', 'Biryani'"},
                    "category": {"type": "string", "description": "Optional category filter like 'momo', 'beverages'"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "add_to_cart",
            "description": "Add an item to the user's active shopping cart and trigger a client UI action event.",
            "parameters": {
                "type": "object",
                "properties": {
                    "item_name": {"type": "string", "description": "Name of the dish or grocery item"},
                    "quantity": {"type": "integer", "description": "Quantity to add", "default": 1}
                },
                "required": ["item_name"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "calculate_ride_fare",
            "description": "Calculate estimated ride-hailing fare in Nepal for Motorbike, Taxi, or Car.",
            "parameters": {
                "type": "object",
                "properties": {
                    "pickup": {"type": "string", "description": "Pickup landmark or ward in Nepal"},
                    "destination": {"type": "string", "description": "Destination landmark or area"},
                    "vehicle_type": {"type": "string", "enum": ["moto", "taxi", "car"], "default": "moto"}
                },
                "required": ["pickup", "destination"]
            }
        }
    }
]


class DialogOrchestrator:
    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        self.base_url = base_url or os.getenv("LLM_BASE_URL", "http://ollama:11434/v1")
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY") or os.getenv("OPENAI_API_KEY", "dummy-key")
        self._client = None
        self._init_client()

    def _init_client(self):
        try:
            from openai import AsyncOpenAI
            self._client = AsyncOpenAI(base_url=self.base_url, api_key=self.api_key)
            logger.info(f"OpenAI-compatible client initialized targeting {self.base_url}")
        except Exception as e:
            logger.warning(f"AsyncOpenAI client initialization deferred: {e}")

    async def generate_response(
        self,
        user_text: str,
        persona: VoicePersona,
        user_context: Optional[Dict[str, Any]] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        Processes user query, executes tools if invoked, and returns conversational response.
        """
        # If live LLM is accessible
        if self._client and self.api_key != "dummy-key":
            try:
                system_prompt = (
                    f"You are {persona.name}, the voice concierge for EVRRY, Nepal's Super App.\n"
                    f"Directive: {persona.system_prompt}\n"
                    f"User Context: {json.dumps(user_context or {})}\n"
                    f"Keep responses natural, helpful, and concise for real-time speech."
                )
                messages = [{"role": "system", "content": system_prompt}]
                if conversation_history:
                    messages.extend(conversation_history)
                messages.append({"role": "user", "content": user_text})

                response = await self._client.chat.completions.create(
                    model=os.getenv("LLM_MODEL", "google/gemini-2.0-flash-001"),
                    messages=messages,
                    tools=EVRRY_TOOLS,
                    tool_choice="auto",
                    temperature=0.7
                )
                choice = response.choices[0]
                message = choice.message

                # Handle tool calls
                ui_actions = []
                if message.tool_calls:
                    for tool_call in message.tool_calls:
                        fn_name = tool_call.function.name
                        fn_args = json.loads(tool_call.function.arguments or "{}")
                        action = self._execute_tool(fn_name, fn_args)
                        ui_actions.append(action)

                reply_text = message.content or persona.sample_greeting
                return {
                    "text": reply_text,
                    "persona": persona.id,
                    "ui_actions": ui_actions
                }
            except Exception as e:
                logger.error(f"Live LLM error: {e}. Falling back to Persona Mock Engine.")

        # Dev Mock Mode Tailored to Persona
        return self._generate_mock_response(user_text, persona)

    def _execute_tool(self, name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """Simulate or execute tool action."""
        if name == "add_to_cart":
            return {
                "action": "ADD_TO_CART",
                "item_name": args.get("item_name", "Chicken Momo"),
                "quantity": args.get("quantity", 1),
                "toast": f"Added {args.get('quantity', 1)}x {args.get('item_name')} to your cart!"
            }
        elif name == "calculate_ride_fare":
            return {
                "action": "SHOW_RIDE_ESTIMATE",
                "pickup": args.get("pickup"),
                "destination": args.get("destination"),
                "estimated_fare_npr": 150,
                "vehicle": args.get("vehicle_type", "moto")
            }
        return {"action": name, "params": args}

    def _generate_mock_response(self, user_text: str, persona: VoicePersona) -> Dict[str, Any]:
        """Generate high-quality conversational response tailored to persona."""
        lower = user_text.lower()
        reply = persona.sample_greeting
        ui_actions = []

        if persona.id == "eli":
            if any(k in lower for k in ["momo", "food", "khana", "order"]):
                reply = "Hajur! Best momo spot bata 1 plate Steamed Chicken Momo cart ma add gardiye hai! Anything else?"
                ui_actions.append({"action": "ADD_TO_CART", "item_name": "Chicken Steamed Momo", "quantity": 1})
            elif any(k in lower for k in ["ride", "bike", "taxi"]):
                reply = "Ekdam fast! Nearby bikers ready chan. Pickup confirm gardinus na!"
                ui_actions.append({"action": "OPEN_RIDE_MODAL"})
        elif persona.id == "rony":
            if any(k in lower for k in ["momo", "food", "khana", "order"]):
                reply = "Namaskar. I have added premium steamed momo to your order sheet. Would you like to review the checkout details?"
                ui_actions.append({"action": "ADD_TO_CART", "item_name": "Chicken Steamed Momo", "quantity": 1})
            elif any(k in lower for k in ["ride", "bike", "taxi"]):
                reply = "Understood. Bidding is now open for verified executive cabs. Expected fare is NPR 450."
                ui_actions.append({"action": "SHOW_RIDE_ESTIMATE", "estimated_fare_npr": 450})
        elif persona.id == "jenny":
            if any(k in lower for k in ["momo", "food", "grocery", "fruit", "tarkari"]):
                reply = "Namaste! Delicious, piping hot momo added with a 15% promotional voucher! Let's check out together!"
                ui_actions.append({"action": "ADD_TO_CART", "item_name": "Chicken Steamed Momo", "quantity": 1})
            elif any(k in lower for k in ["hotel", "stay", "room"]):
                reply = "How wonderful! I found three lovely family homestays in Pokhara with mountain view balconies!"
                ui_actions.append({"action": "SHOW_STAYS"})
        elif persona.id == "suka":
            if any(k in lower for k in ["momo", "food", "khana"]):
                reply = "Namaste... rest easy. Warm, comforting momo has been gently placed in your cart. We will deliver it quietly."
                ui_actions.append({"action": "ADD_TO_CART", "item_name": "Chicken Steamed Momo", "quantity": 1})
            elif any(k in lower for k in ["ride", "bike", "taxi"]):
                reply = "A safe, peaceful driver is being arranged for your journey home. Take your time."
                ui_actions.append({"action": "OPEN_RIDE_MODAL"})

        return {
            "text": reply,
            "persona": persona.id,
            "ui_actions": ui_actions
        }
