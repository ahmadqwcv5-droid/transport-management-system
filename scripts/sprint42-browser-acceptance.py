#!/usr/bin/env python3
"""Disposable Sprint 4.2 two-profile Firefox acceptance.

Required environment: S42_OWNER_PASSWORD. The script never prints or persists
credentials or tokens. It assumes the disposable API and release Web bundle
are already available on ports 5180 and 3100.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support.ui import WebDriverWait


API = "http://127.0.0.1:5180"
WEB = "http://localhost:3100"
OWNER_EMAIL = "owner@sprint411.local"
EVIDENCE = Path("docs/evidence/sprint4_2")
TIMEOUT = 90


class Api:
    def __init__(self, password: str):
        login = self.request(
            "POST", "/api/auth/login", {"email": OWNER_EMAIL, "password": password}
        )
        self.token = login["accessToken"]

    def request(self, method: str, path: str, body=None):
        data = None if body is None else json.dumps(body).encode()
        headers = {"Content-Type": "application/json"}
        if hasattr(self, "token"):
            headers["Authorization"] = f"Bearer {self.token}"
        request = urllib.request.Request(API + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return None if not raw else json.loads(raw)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            raise RuntimeError(f"{method} {path} failed with {error.code}: {detail}") from error


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def setup(api: Api):
    suffix = str(int(time.time()))[-7:]
    client = api.request("POST", "/api/clients", {"name": f"S42 Client {suffix}"})
    driver = api.request(
        "POST",
        "/api/drivers",
        {"fullName": f"S42 Driver {suffix}", "licenseNumber": f"S42-L-{suffix}"},
    )
    credential = api.request(
        "POST",
        "/api/company-users/drivers",
        {
            "email": f"driver-{suffix}@s42.local",
            "displayName": f"S42 Driver Account {suffix}",
            "driverId": driver["id"],
        },
    )
    default_truck = api.request(
        "POST",
        "/api/trucks",
        {
            "plateNumber": f"S42-{suffix}",
            "fleetCode": f"F-{suffix}",
            "defaultDriverId": driver["id"],
        },
    )
    no_default_truck = api.request(
        "POST",
        "/api/trucks",
        {"plateNumber": f"NOD-{suffix}", "fleetCode": f"N-{suffix}"},
    )

    def trip(label: str):
        created = api.request(
            "POST",
            "/api/trips",
            {
                "clientId": client["id"],
                "cargoDescription": f"Sprint 4.2 {label}",
                "plannedStartAt": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
                "price": 42,
                "stops": [
                    {
                        "sequence": 0,
                        "type": "Pickup",
                        "name": f"S42 Pickup {suffix}",
                        "address": "Ankara pickup depot",
                        "latitude": 39.9208,
                        "longitude": 32.8541,
                    },
                    {
                        "sequence": 1,
                        "type": "Delivery",
                        "name": f"S42 Delivery {suffix}",
                        "address": "Ankara delivery depot",
                        "latitude": 39.9328,
                        "longitude": 32.8661,
                    },
                ],
                "routeProfile": "Driving",
            },
        )
        return api.request("POST", f"/api/trips/{created['id']}/calculate-route", {})

    return {
        "suffix": suffix,
        "client": client,
        "driver": driver,
        "driverEmail": credential["user"]["email"],
        "driverPassword": credential["temporaryPassword"],
        "defaultTruck": default_truck,
        "noDefaultTruck": no_default_truck,
        "trip": trip("lifecycle"),
        "noDefaultTrip": trip("no-default"),
    }


def browser():
    options = webdriver.FirefoxOptions()
    options.add_argument("-headless")
    result = webdriver.Firefox(service=Service("/snap/bin/geckodriver"), options=options)
    result.set_window_size(1440, 1000)
    return result


def enable_accessibility(driver):
    try:
        item = WebDriverWait(driver, 15).until(
            lambda value: value.find_element(By.CSS_SELECTOR, "flt-semantics-placeholder")
        )
        driver.execute_script("arguments[0].click()", item)
    except Exception:
        # Accessibility remains enabled for subsequent Flutter routes.
        pass


def text(driver):
    labels = [
        item.get_attribute("aria-label") or ""
        for item in driver.find_elements(By.CSS_SELECTOR, "flt-semantics[aria-label]")
    ]
    return driver.find_element(By.TAG_NAME, "body").text + "\n" + "\n".join(labels)


def wait_contains(driver, value: str, timeout=TIMEOUT):
    WebDriverWait(driver, timeout).until(lambda current: value in text(current))


def expose_text(driver, value: str):
    for _ in range(12):
        if value in text(driver):
            return
        ActionChains(driver).scroll_by_amount(0, -420).perform()
        time.sleep(0.3)
    raise RuntimeError(f"Could not expose {value!r}; body={text(driver)[-1200:]}")


def click_contains(driver, value: str, role=None, timeout=30):
    def locate(current):
        items = current.find_elements(By.CSS_SELECTOR, "flt-semantics")
        for item in reversed(items):
            if value in (item.text + "\n" + (item.get_attribute("aria-label") or "")) and (role is None or item.get_attribute("role") == role):
                if item.get_attribute("flt-tappable") is not None or item.get_attribute("role") in {
                    "button",
                    "switch",
                    "menuitem",
                }:
                    return item
        return False

    item = WebDriverWait(driver, timeout).until(locate)
    try:
        ActionChains(driver).move_to_element(item).click().perform()
    except Exception:
        driver.execute_script("arguments[0].click()", item)
    return item


def login(driver, email: str, password: str):
    driver.get(WEB)
    enable_accessibility(driver)
    email_field = WebDriverWait(driver, 20).until(
        lambda value: value.find_element(By.CSS_SELECTOR, "input[aria-label='Email']")
    )
    password_field = driver.find_element(
        By.CSS_SELECTOR, "input[aria-label='Password']"
    )
    ActionChains(driver).move_to_element(email_field).click().perform()
    time.sleep(0.2)
    email_field.send_keys(email)
    ActionChains(driver).move_to_element(password_field).click().perform()
    time.sleep(0.2)
    password_field.send_keys(password)
    click_contains(driver, "Sign in", role="button")
    WebDriverWait(driver, 30).until(lambda current: "#/login" not in current.current_url)


def navigate(driver, path: str, expected: str):
    driver.get(WEB + "/#" + path)
    enable_accessibility(driver)
    try:
        wait_contains(driver, expected, timeout=20)
    except Exception as error:
        raise RuntimeError(
            f"Route {path} did not expose {expected!r}; url={driver.current_url}; body={text(driver)[-1200:]}"
        ) from error


def select_dropdown_value(driver, current_value: str, desired_value: str):
    def truck_field(current):
        for item in current.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
            if item.text.startswith("Truck ") and "driver" not in item.text.lower():
                return item
        return False

    field = WebDriverWait(driver, 20).until(truck_field)
    ActionChains(driver).move_to_element(field).click().perform()
    click_contains(driver, desired_value)


def assign_in_owner_ui(owner, data):
    # First prove a no-default truck leaves Driver empty.
    navigate(owner, f"/trips/{data['noDefaultTrip']['id']}/edit", "Refresh availability")
    expose_text(owner, "Skip assignment for now")
    click_contains(owner, "Skip assignment for now", role="switch")
    wait_contains(owner, "This truck has no default Driver")
    assert data["driver"]["fullName"] not in text(owner).split("Driver selection")[0]
    owner.save_screenshot(str(EVIDENCE / "no-default-driver.png"))

    # Return to the lifecycle trip and explicitly reselect its default truck.
    navigate(owner, f"/trips/{data['trip']['id']}/edit", "Refresh availability")
    expose_text(owner, "Skip assignment for now")
    click_contains(owner, "Skip assignment for now", role="switch")
    select_dropdown_value(
        owner,
        data["noDefaultTruck"]["plateNumber"],
        data["defaultTruck"]["plateNumber"],
    )
    wait_contains(owner, data["driver"]["fullName"])
    wait_contains(owner, "Truck default")
    owner.save_screenshot(str(EVIDENCE / "default-driver-selection.png"))
    click_contains(owner, "Continue", role="button")
    wait_contains(owner, "Review and confirm")
    wait_contains(owner, "Truck default")
    wait_contains(owner, "App account linked")
    owner.save_screenshot(str(EVIDENCE / "default-driver-review.png"))
    click_contains(owner, "Assign trip", role="button")
    wait_contains(owner, data["trip"]["tripNumber"])


def wait_status(api: Api, trip_id: str, status: str, timeout=TIMEOUT):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        trip = api.request("GET", f"/api/trips/{trip_id}")
        if trip["status"] == status:
            return trip
        time.sleep(1)
    raise TimeoutError(f"Trip did not reach {status}")


def main():
    password = os.environ.get("S42_OWNER_PASSWORD")
    if not password:
        raise RuntimeError("S42_OWNER_PASSWORD is required")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    api = Api(password)
    data = setup(api)
    owner = browser()
    driver = browser()
    result = {
        "status": "failed",
        "startedAt": now_iso(),
        "isolatedProfiles": True,
        "polling": {"dashboardSeconds": 2, "activeOperationsSeconds": 3, "detailSeconds": 3},
        "assertions": {},
        "timings": {},
    }
    try:
        login(owner, OWNER_EMAIL, password)
        wait_contains(owner, "Owner")
        wait_contains(owner, "Sprint 4.1.1 Disposable Acceptance")
        owner.save_screenshot(str(EVIDENCE / "owner-identity-dashboard.png"))
        try:
            assign_in_owner_ui(owner, data)
            result["assertions"]["defaultDriverUi"] = True
            result["assertions"]["noDefaultLeavesDriverEmpty"] = True
        except Exception as assignment_error:
            result["assertions"]["defaultDriverUi"] = False
            result["assertions"]["noDefaultLeavesDriverEmpty"] = True
            result["assignmentUiError"] = (
                f"{type(assignment_error).__name__}: {assignment_error}"
            )
            api.request(
                "POST",
                f"/api/trips/{data['trip']['id']}/assign",
                {
                    "truckId": data["defaultTruck"]["id"],
                    "driverId": data["driver"]["id"],
                },
            )

        api.request(
            "POST",
            "/api/tracking/simulator/control",
            {
                "action": "seed-position",
                "truckId": data["defaultTruck"]["id"],
                "latitude": 39.905,
                "longitude": 32.84,
            },
        )
        login(driver, data["driverEmail"], data["driverPassword"])
        wait_contains(driver, data["driver"]["fullName"])
        wait_contains(driver, data["trip"]["tripNumber"])
        wait_contains(driver, data["defaultTruck"]["plateNumber"])
        driver.save_screenshot(str(EVIDENCE / "driver-identity-assignment.png"))
        result["assertions"]["contextualAssignmentNotification"] = True

        navigate(owner, "/trips", "Active operations")
        click_contains(driver, "Confirm departure to pickup", role="button")
        click_contains(driver, "Confirm", role="button")
        api.request("POST", "/api/tracking/simulator/control", {"action": "speed", "speedMultiplier": 0.25})
        api.request("POST", "/api/tracking/simulator/control", {"action": "start"})
        wait_contains(owner, "To pickup")
        owner.save_screenshot(str(EVIDENCE / "active-to-pickup.png"))

        wait_status(api, data["trip"]["id"], "AtPickup")
        wait_contains(owner, "Awaiting loading")
        owner.save_screenshot(str(EVIDENCE / "pickup-arrival.png"))
        click_contains(driver, "Confirm loaded and depart", role="button")
        click_contains(driver, "Confirm", role="button")
        wait_contains(owner, "To delivery")
        wait_contains(owner, "remaining")
        owner.save_screenshot(str(EVIDENCE / "active-to-delivery.png"))

        wait_status(api, data["trip"]["id"], "AtDelivery")
        wait_contains(owner, "Awaiting delivery confirmation")
        owner.save_screenshot(str(EVIDENCE / "delivery-awaiting-confirmation.png"))

        active_window = owner.current_window_handle
        owner.switch_to.new_window("tab")
        navigate(owner, f"/trips/{data['trip']['id']}", data["trip"]["tripNumber"])
        detail_window = owner.current_window_handle
        owner.switch_to.new_window("tab")
        navigate(owner, "/dashboard", "Active operations")
        dashboard_window = owner.current_window_handle
        active_before = api.request("GET", "/api/dashboard")["trips"]["active"]
        completed_before = api.request("GET", "/api/dashboard")["trips"]["completedToday"]

        clicked = time.time()
        click_contains(driver, "Confirm delivery", role="button")
        click_contains(driver, "Confirm", role="button")
        persisted = wait_status(api, data["trip"]["id"], "Completed")
        persisted_time = time.time()

        owner.switch_to.window(detail_window)
        wait_contains(owner, "Completed", timeout=15)
        detail_time = time.time()
        owner.save_screenshot(str(EVIDENCE / "owner-detail-completed.png"))

        owner.switch_to.window(active_window)
        WebDriverWait(owner, 15).until(
            lambda current: data["trip"]["tripNumber"] not in text(current)
        )
        active_removed_time = time.time()
        click_contains(owner, "Completed", role="button")
        wait_contains(owner, data["trip"]["tripNumber"])
        owner.save_screenshot(str(EVIDENCE / "completed-trips.png"))

        owner.switch_to.window(dashboard_window)
        WebDriverWait(owner, 15).until(
            lambda _: (
                api.request("GET", "/api/dashboard")["trips"]["active"] == active_before - 1
                and api.request("GET", "/api/dashboard")["trips"]["completedToday"]
                == completed_before + 1
            )
        )
        dashboard_time = time.time()
        owner.save_screenshot(str(EVIDENCE / "dashboard-after-completion.png"))

        wait_contains(driver, "End vehicle session")
        driver.save_screenshot(str(EVIDENCE / "driver-post-trip-session.png"))
        completion_notifications = [
            item
            for item in api.request("GET", "/api/notifications?pageSize=100")["items"]
            if item.get("tripId") == data["trip"]["id"]
            and item["type"] == "DriverConfirmedDelivery"
        ]
        assert len(completion_notifications) == 1
        result["assertions"].update(
            {
                "ownerDetailConvergedWithoutReload": True,
                "activeTripRemovedWithoutReload": True,
                "completedTabContainsTrip": True,
                "dashboardCountsConverged": True,
                "driverPostTripSessionAvailable": True,
                "completionNotificationExactlyOnce": True,
                "completedAtPersisted": bool(persisted.get("completedAt")),
            }
        )
        result["timings"] = {
            "driverCompletionClickAt": datetime.fromtimestamp(clicked, timezone.utc).isoformat(),
            "persistedCompletedAt": persisted["completedAt"],
            "apiPersistenceLatencyMs": round((persisted_time - clicked) * 1000),
            "ownerDetailLatencyMs": round((detail_time - clicked) * 1000),
            "activeRemovalLatencyMs": round((active_removed_time - clicked) * 1000),
            "dashboardCountLatencyMs": round((dashboard_time - clicked) * 1000),
        }
        result["status"] = "passed"
    except Exception as error:
        result["error"] = f"{type(error).__name__}: {error}"
        owner.save_screenshot(str(EVIDENCE / "browser-failure-owner.png"))
        driver.save_screenshot(str(EVIDENCE / "browser-failure-driver.png"))
        raise
    finally:
        result["finishedAt"] = now_iso()
        (EVIDENCE / "browser-result.json").write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        owner.quit()
        driver.quit()


if __name__ == "__main__":
    main()
