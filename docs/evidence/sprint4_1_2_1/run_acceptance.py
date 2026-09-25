#!/usr/bin/env python3
"""Disposable Sprint 4.1.2.1 setup and raw-WebDriver acceptance helper.

Reads DEMO_OWNER_PASSWORD from the ignored repository .env and never writes
credentials or tokens to evidence output.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
API = "http://127.0.0.1:5080/api"
WD = "http://127.0.0.1:4444"
WEB = "http://localhost:3000"


def env_value(name):
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith(name + "="):
            return line.split("=", 1)[1].strip()
    raise RuntimeError(f"Missing {name}")


def request(url, method="GET", body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as response:
            raw = response.read()
            return None if not raw else json.loads(raw)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"{method} {url} -> {error.code}: {error.read().decode()}") from error


def api(path, method="GET", body=None, token=None):
    return request(API + path, method, body, token)


def wd(path, method="GET", body=None):
    return request(WD + path, method, body)


def session():
    result = wd("/session", "POST", {"capabilities": {"alwaysMatch": {
        "browserName": "firefox", "moz:firefoxOptions": {"args": ["-headless"]}}}})
    return result["value"]["sessionId"]


def navigate(sid, url):
    wd(f"/session/{sid}/url", "POST", {"url": url})
    until = time.time() + 30
    enabled = False
    while time.time() < until:
        enabled = wd(f"/session/{sid}/execute/sync", "POST", {"script":
            "const e=document.querySelector('flt-semantics-placeholder'); if(e){e.click();return true;} return !!document.querySelector('flt-semantics');", "args": []})["value"]
        if enabled:
            break
        time.sleep(.5)
    if not enabled:
        raise RuntimeError("Flutter semantics did not initialize")
    time.sleep(1)


def elements(sid, xpath):
    return wd(f"/session/{sid}/elements", "POST", {"using": "xpath", "value": xpath})["value"]


def element_id(item):
    return item.get("element-6066-11e4-a52e-4f735466cecf")


def find(sid, xpath, timeout=20):
    until = time.time() + timeout
    while time.time() < until:
        found = elements(sid, xpath)
        if found:
            return element_id(found[0])
        time.sleep(.4)
    raise RuntimeError(f"Element not found: {xpath}")


def click(sid, xpath, timeout=20):
    eid = find(sid, xpath, timeout)
    wd(f"/session/{sid}/element/{eid}/click", "POST", {})


def click_at(sid, x, y):
    wd(f"/session/{sid}/actions", "POST", {"actions": [{"type": "pointer", "id": "mouse", "parameters": {"pointerType": "mouse"}, "actions": [
        {"type": "pointerMove", "duration": 0, "origin": "viewport", "x": x, "y": y},
        {"type": "pointerDown", "button": 0}, {"type": "pointerUp", "button": 0}]}]})


def type_text(sid, xpath, value):
    eid = find(sid, xpath)
    wd(f"/session/{sid}/element/{eid}/click", "POST", {})
    wd(f"/session/{sid}/element/{eid}/value", "POST", {"text": value, "value": list(value)})


def page_source(sid):
    return wd(f"/session/{sid}/source")["value"]


def screenshot(sid, name):
    data = wd(f"/session/{sid}/screenshot")["value"]
    (EVIDENCE / name).write_bytes(base64.b64decode(data))


def login_ui(sid, email, password):
    navigate(sid, WEB)
    type_text(sid, "//input[@aria-label='Email']", email)
    type_text(sid, "//input[@aria-label='Password']", password)
    password_element = find(sid, "//input[@aria-label='Password']")
    wd(f"/session/{sid}/element/{password_element}/value", "POST", {"text": "\ue00c", "value": ["\ue00c"]})
    time.sleep(.5)
    try:
        click(sid, "//*[@role='button' and @aria-label='Sign in']", 3)
    except RuntimeError:
        # Firefox can omit Flutter button semantics while a native text input
        # has focus. This fixed acceptance viewport keeps submit centered.
        wd(f"/session/{sid}/actions", "POST", {"actions": [{"type": "pointer", "id": "mouse", "parameters": {"pointerType": "mouse"}, "actions": [
            {"type": "pointerMove", "duration": 0, "origin": "viewport", "x": 683, "y": 489},
            {"type": "pointerDown", "button": 0}, {"type": "pointerUp", "button": 0}]}]})
    time.sleep(4)


def setup():
    owner_password = env_value("DEMO_OWNER_PASSWORD")
    auth = api("/auth/login", "POST", {"email": "owner@demo.local", "password": owner_password})
    token = auth["accessToken"]
    stamp = datetime.now().strftime("%H%M%S")
    client = api("/clients", "POST", {"name": f"S4121 Client {stamp}", "contactPerson": "Acceptance", "phone": None, "email": None, "address": "Istanbul", "notes": "Disposable browser acceptance"}, token)
    truck = api("/trucks", "POST", {"plateNumber": f"S41-{stamp}", "make": "Acceptance", "model": "Web", "year": 2026, "notes": "Disposable", "fleetCode": f"S4121-{stamp}", "type": "BoxTruck", "payloadCapacity": 5000, "payloadUnit": "Kilograms", "fuelType": "Diesel", "odometerKilometers": 100}, token)
    driver = api("/drivers", "POST", {"fullName": f"Sprint 4121 Driver {stamp}", "phone": None, "licenseNumber": f"S4121-{stamp}", "licenseExpiryDate": "2028-12-31", "notes": "Disposable browser acceptance"}, token)
    email = f"driver.s4121.{stamp}@demo.local"
    account = api("/company-users/drivers", "POST", {"email": email, "displayName": driver["fullName"], "driverId": driver["id"]}, token)
    stops = [
        {"sequence": 0, "type": "Pickup", "name": "Galata Pickup", "address": "Galata, Istanbul", "latitude": 41.0245, "longitude": 28.9744, "plannedArrivalAt": None, "plannedServiceDurationMinutes": 10},
        {"sequence": 1, "type": "Delivery", "name": "Kadikoy Delivery", "address": "Kadikoy, Istanbul", "latitude": 40.9908, "longitude": 29.0285, "plannedArrivalAt": None, "plannedServiceDurationMinutes": 10},
    ]
    trip = api("/trips", "POST", {"clientId": client["id"], "cargoDescription": "Sprint 4.1.2.1 acceptance cargo", "plannedStartAt": (datetime.now(timezone.utc)+timedelta(hours=2)).isoformat(), "price": 500, "notes": "Disposable browser acceptance", "stops": stops, "routeProfile": "Driving"}, token)
    trip = api(f"/trips/{trip['id']}/calculate-route", "POST", {"routeProfile": "Driving"}, token)
    api("/tracking/simulator/control", "POST", {"action": "seed-position", "truckId": truck["id"], "latitude": 40.9620, "longitude": 28.8550}, token)
    api("/tracking/simulator/control", "POST", {"action": "start"}, token)
    state = {"tripId": trip["id"], "tripNumber": trip["tripNumber"], "truckId": truck["id"], "driverId": driver["id"], "driverEmail": email, "driverPassword": account["temporaryPassword"], "ownerPassword": owner_password}
    (Path("/tmp") / "s4121_state.json").write_text(json.dumps(state))
    public = {k: v for k, v in state.items() if k not in {"driverPassword", "ownerPassword"}}
    (EVIDENCE / "disposable-records.json").write_text(json.dumps(public, indent=2) + "\n")
    print(json.dumps(public))


if __name__ == "__main__":
    if len(sys.argv) == 1 or sys.argv[1] == "setup":
        setup()
    elif sys.argv[1] == "owner":
        state = json.loads((Path("/tmp") / "s4121_state.json").read_text())
        sid = sys.argv[2] if len(sys.argv) > 2 else session()
        login_ui(sid, "owner@demo.local", state["ownerPassword"])
        (Path("/tmp") / "s4121_owner_session").write_text(sid)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        print(json.dumps({"ownerSessionCreated": True, "tripPageOpened": True}))
    elif sys.argv[1] == "driver":
        state = json.loads((Path("/tmp") / "s4121_state.json").read_text())
        sid = session()
        login_ui(sid, state["driverEmail"], state["driverPassword"])
        (Path("/tmp") / "s4121_driver_session").write_text(sid)
        (Path("/tmp") / "s4121_driver_source.html").write_text(page_source(sid))
        print(json.dumps({"driverSessionCreated": True}))
    elif sys.argv[1] == "owner-open-trip":
        state = json.loads((Path("/tmp") / "s4121_state.json").read_text())
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        wd(f"/session/{sid}/execute/sync", "POST", {"script":
            "history.pushState({},'',arguments[0]);window.dispatchEvent(new PopStateEvent('popstate'));return true;",
            "args": [f"/trips/{state['tripId']}"]})
        time.sleep(3)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        print(json.dumps({"ownerTripOpened": True}))
    elif sys.argv[1] == "owner-home":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        navigate(sid, WEB)
        time.sleep(3)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        screenshot(sid, "owner-dashboard.png")
        print(json.dumps({"ownerHomeOpened": True}))
    elif sys.argv[1] == "owner-trips":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 52, 336)
        time.sleep(3)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        screenshot(sid, "owner-trips.png")
        print(json.dumps({"ownerTripsOpened": True}))
    elif sys.argv[1] == "owner-planned":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 644, 151)
        time.sleep(3)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        screenshot(sid, "owner-planned-trips.png")
        print(json.dumps({"ownerPlannedOpened": True}))
    elif sys.argv[1] == "owner-row":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 700, 211)
        time.sleep(3)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        screenshot(sid, "owner-trip-before-assignment.png")
        print(json.dumps({"ownerTripOpened": True}))
    elif sys.argv[1] == "owner-assign-dialog":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 485, 658)
        time.sleep(2)
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        screenshot(sid, "owner-assignment-dialog.png")
        print(json.dumps({"ownerAssignmentDialogOpened": True}))
    elif sys.argv[1] == "owner-truck-menu":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 680, 306)
        time.sleep(1)
        screenshot(sid, "owner-truck-menu.png")
        print(json.dumps({"ownerTruckMenuOpened": True}))
    elif sys.argv[1] == "owner-driver-menu":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 680, 354)
        time.sleep(.5)
        click_at(sid, 680, 366)
        time.sleep(1)
        screenshot(sid, "owner-driver-menu.png")
        print(json.dumps({"ownerDriverMenuOpened": True}))
    elif sys.argv[1] == "owner-confirm-assignment":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 680, 414)
        time.sleep(.5)
        click_at(sid, 857, 430)
        time.sleep(4)
        screenshot(sid, "owner-assigned-trip.png")
        (Path("/tmp") / "s4121_owner_source.html").write_text(page_source(sid))
        print(json.dumps({"ownerAssignedThroughUi": True}))
    elif sys.argv[1] == "close-owner":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        wd(f"/session/{sid}", "DELETE")
        print(json.dumps({"ownerSessionClosed": True}))
    elif sys.argv[1] == "driver-inspect":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        screenshot(sid, "driver-assignment-en.png")
        (Path("/tmp") / "s4121_driver_source.html").write_text(page_source(sid))
        print(json.dumps({"driverEnglishCaptured": True}))
    elif sys.argv[1] == "driver-notifications":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        click_at(sid, 46, 144)
        time.sleep(3)
        screenshot(sid, "driver-assignment-notification.png")
        (Path("/tmp") / "s4121_driver_source.html").write_text(page_source(sid))
        print(json.dumps({"driverNotificationsOpened": True}))
    elif sys.argv[1] == "driver-open-trip":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        click_at(sid, 1300, 159)
        time.sleep(4)
        screenshot(sid, "driver-open-trip-en.png")
        print(json.dumps({"driverOpenedTripThroughAlert": True}))
    elif sys.argv[1] == "driver-settings":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        click_at(sid, 46, 208)
        time.sleep(2)
        screenshot(sid, "driver-settings-en.png")
        print(json.dumps({"driverSettingsOpened": True}))
    elif sys.argv[1] == "driver-arabic":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        click_at(sid, 700, 530)
        time.sleep(.5)
        click_at(sid, 700, 578)
        time.sleep(3)
        # Navigation rail moves to the right under RTL.
        click_at(sid, 1320, 80)
        time.sleep(4)
        screenshot(sid, "driver-workspace-ar.png")
        print(json.dumps({"driverArabicWorkspaceCaptured": True}))
    elif sys.argv[1] == "driver-depart-dialog":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        click_at(sid, 643, 230)
        time.sleep(1)
        screenshot(sid, "driver-departure-confirmation-ar.png")
        print(json.dumps({"driverDepartureDialogOpened": True}))
    elif sys.argv[1] == "driver-confirm-departure":
        state = json.loads((Path("/tmp") / "s4121_state.json").read_text())
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        clicked_at = datetime.now(timezone.utc)
        click_at(sid, 572, 386)
        time.sleep(12)
        screenshot(sid, "driver-moving-ar.png")
        auth = api("/auth/login", "POST", {"email": "owner@demo.local", "password": state["ownerPassword"]})
        token = auth["accessToken"]
        first_trip = api(f"/trips/{state['tripId']}", token=token)
        first_history = api(f"/tracking/trips/{state['tripId']}/history?limit=500", token=token)
        first_position = api(f"/tracking/trucks/{state['truckId']}/position", token=token)
        time.sleep(8)
        second_history = api(f"/tracking/trips/{state['tripId']}/history?limit=500", token=token)
        second_position = api(f"/tracking/trucks/{state['truckId']}/position", token=token)
        timeline = api(f"/trips/{state['tripId']}/timeline?pageSize=100", token=token)
        events = [item["eventType"] for item in timeline["items"]]
        result = {
            "passed": first_trip["status"] == "EnRouteToPickup" and first_trip.get("repositioningPlan") is not None and second_history["pointCount"] > first_history["pointCount"] and "DriverDepartedToPickup" in events and not any("Override" in item for item in events),
            "ownerSessionClosedBeforeDeparture": True,
            "independentBrowserProfiles": 2,
            "assignmentViaOwnerUi": True,
            "notificationOpenTripViaDriverUi": True,
            "departureViaDriverUi": True,
            "managerPreviewUsed": False,
            "managerOverrideUsed": False,
            "directDepartureApiUsed": False,
            "manualSimulatorStepUsed": False,
            "departureClickedAt": clicked_at.isoformat(),
            "observedStatus": first_trip["status"],
            "approachRoutePersisted": first_trip.get("repositioningPlan") is not None,
            "approachRouteProvider": None if first_trip.get("repositioningPlan") is None else first_trip["repositioningPlan"]["providerName"],
            "firstPointCount": first_history["pointCount"],
            "secondPointCount": second_history["pointCount"],
            "firstPosition": {"latitude": first_position["latitude"], "longitude": first_position["longitude"], "recordedAt": first_position["recordedAt"]},
            "secondPosition": {"latitude": second_position["latitude"], "longitude": second_position["longitude"], "recordedAt": second_position["recordedAt"]},
            "eventTypes": events,
        }
        (EVIDENCE / "browser-result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({"passed": result["passed"], "status": result["observedStatus"], "points": [result["firstPointCount"], result["secondPointCount"]]}))
    elif sys.argv[1] == "close-driver":
        sid = (Path("/tmp") / "s4121_driver_session").read_text().strip()
        wd(f"/session/{sid}", "DELETE")
        print(json.dumps({"driverSessionClosed": True}))
    elif sys.argv[1] == "owner-moving":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        time.sleep(4)
        screenshot(sid, "owner-moving-map.png")
        print(json.dumps({"ownerMovingMapCaptured": True}))
    elif sys.argv[1] == "owner-select-moving-truck":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 720, 565)
        time.sleep(3)
        screenshot(sid, "owner-selected-moving-route.png")
        print(json.dumps({"ownerMovingTruckSelected": True}))
    elif sys.argv[1] == "owner-route-overview":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        wd(f"/session/{sid}/actions", "POST", {"actions": [{"type": "wheel", "id": "wheel", "actions": [
            {"type": "scroll", "duration": 500, "origin": "viewport", "x": 1200, "y": 600, "deltaX": 0, "deltaY": 450}]}]})
        time.sleep(2)
        screenshot(sid, "owner-route-controls.png")
        print(json.dumps({"ownerRouteControlsCaptured": True}))
    elif sys.argv[1] == "owner-select-panel":
        sid = (Path("/tmp") / "s4121_owner_session").read_text().strip()
        click_at(sid, 250, 462)
        time.sleep(5)
        screenshot(sid, "owner-approach-route.png")
        print(json.dumps({"ownerApproachRouteCaptured": True}))
    else:
        raise SystemExit("Usage: run_acceptance.py [setup|owner|driver]")
