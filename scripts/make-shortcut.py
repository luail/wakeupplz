"""Build the unsigned 'WakeUpPlz 문자 발송' shortcut: ask the app for a pending send request,
then message each recipient. Sign before importing:
  python3 scripts/make-shortcut.py out.shortcut && shortcuts sign --mode anyone -i out.shortcut -o signed.shortcut
"""
import plistlib
import sys
import uuid

def new_id(): return str(uuid.uuid4()).upper()
def output(action_id, name):
    return {"Value": {"OutputUUID": action_id, "Type": "ActionOutput", "OutputName": name}, "WFSerializationType": "WFTextTokenAttachment"}
def text_of(action_id, name):
    return {"Value": {"string": "￼", "attachmentsByRange": {"{0, 1}": {"OutputUUID": action_id, "Type": "ActionOutput", "OutputName": name}}}, "WFSerializationType": "WFTextTokenString"}

request, dictionary, text, recipients, group = (new_id() for _ in range(5))
intent_name = "WakeUpPlz 미인증 발송 요청 가져오기"
actions = [
    # Returns "" unless a 1-minute slot is due and today is still unverified, so nothing is sent otherwise.
    {"WFWorkflowActionIdentifier": "com.luail.WakeUpPlz.PendingMessageIntent", "WFWorkflowActionParameters": {
        "UUID": request,
        "AppIntentDescriptor": {"TeamIdentifier": "REDACTED", "BundleIdentifier": "com.luail.WakeUpPlz", "Name": "WakeUpPlz", "AppIntentIdentifier": "PendingMessageIntent"}}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.detect.dictionary", "WFWorkflowActionParameters": {
        "UUID": dictionary, "WFInput": output(request, intent_name)}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey", "WFWorkflowActionParameters": {
        "UUID": text, "WFInput": output(dictionary, "사전"), "WFDictionaryKey": "text", "CustomOutputName": "문자 내용"}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey", "WFWorkflowActionParameters": {
        "UUID": recipients, "WFInput": output(dictionary, "사전"), "WFDictionaryKey": "recipients", "CustomOutputName": "받는 사람"}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.repeat.each", "WFWorkflowActionParameters": {
        "GroupingIdentifier": group, "WFControlFlowMode": 0, "WFInput": output(recipients, "받는 사람")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.sendmessage", "WFWorkflowActionParameters": {
        "ShowWhenRun": False,
        "WFSendMessageContent": text_of(text, "문자 내용"),
        "WFSendMessageActionRecipients": {"Value": {"Type": "Variable", "VariableName": "Repeat Item"}, "WFSerializationType": "WFTextTokenAttachment"}}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.repeat.each", "WFWorkflowActionParameters": {
        "GroupingIdentifier": group, "WFControlFlowMode": 2, "UUID": new_id()}},
]
workflow = {
    "WFWorkflowClientVersion": "2700.0",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowTypes": [],
    "WFWorkflowHasShortcutInputVariables": False,
    "WFWorkflowActions": actions,
}
with open(sys.argv[1], "wb") as f:
    plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
