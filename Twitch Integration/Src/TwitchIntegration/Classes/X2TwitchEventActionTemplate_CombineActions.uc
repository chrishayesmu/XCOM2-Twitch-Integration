class X2TwitchEventActionTemplate_CombineActions extends X2TwitchEventActionTemplate_TargetsUnits;

var config array<Name> ActionNames;

var privatewrite array<X2TwitchEventActionTemplate> ActionTemplates;

// This action is valid as long as any of its subactions are valid
function bool IsValid(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false) {
    local X2TwitchEventActionTemplate Template;

    CacheTemplates();

    foreach ActionTemplates(Template) {
        if (Template.IsValid(InvokingUnit, ForceUseProvidedUnit)) {
            return true;
        }
    }

    return false;
}

function Apply(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false) {
    local X2TwitchEventActionTemplate Template;
    local X2TwitchEventActionTemplate_TargetsUnits TargetsUnitTemplate;
    local array<XComGameState_Unit> TargetUnits;
    local XComGameState_Unit Unit;

    CacheTemplates();

    // TODO: we should probably rank targets by how many actions they're valid for
    TargetUnits = FindTargets(InvokingUnit, ForceUseProvidedUnit);
    `TILOG("Applying " $ ActionTemplates.Length $ " action templates to " $ TargetUnits.Length $ " units");

    // Iterate twice: once over all units, invoking only the actions that target units;
    // then again over all templates, invoking only the actions that don't target units
    foreach TargetUnits(Unit) {
        foreach ActionTemplates(Template) {
            TargetsUnitTemplate = X2TwitchEventActionTemplate_TargetsUnits(Template);

            if (TargetsUnitTemplate == none) {
                continue;
            }

            // Target may only be valid for some action templates
            if (TargetsUnitTemplate.IsValidTarget(Unit)) {
                `TILOG("Unit is a valid target, applying action " $ Template.Class.Name);
                TargetsUnitTemplate.Apply(Unit);
            }
            else {
                `TILOG("Unit is not a valid target, skipping action " $ Template.Class.Name);
            }
        }
    }

    // Now again for non-unit templates
    foreach ActionTemplates(Template) {
        if (Template.IsA('X2TwitchEventActionTemplate_TargetsUnits')) {
            continue;
        }

        `TILOG("Applying non-unit action template " $ Template.Class.Name);
        Template.Apply(/* InvokingUnit */ none);
    }
}

protected function bool IsValidTarget(XComGameState_Unit Unit) {
    local X2TwitchEventActionTemplate Template;
    local X2TwitchEventActionTemplate_TargetsUnits TargetsUnitTemplate;

    foreach ActionTemplates(Template) {
        TargetsUnitTemplate = X2TwitchEventActionTemplate_TargetsUnits(Template);

        if (TargetsUnitTemplate == none) {
            continue;
        }

        if (TargetsUnitTemplate.IsValidTarget(Unit)) {
            return true;
        }
    }

    return false;
}

private function CacheTemplates() {
    local int Index;

    if (ActionTemplates.Length > 0) {
        return;
    }

    ActionTemplates.Length = ActionNames.Length;

    for (Index = 0; Index < ActionNames.Length; Index++) {
        ActionTemplates[Index] = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionNames[Index]);

        if (ActionTemplates[Index] == none) {
            `TILOG("ERROR: Could not load action named '" $ ActionNames[Index] $ "'. This is likely a configuration error.");
        }
    }
}