// Documentation available at https://donadigo.com/tminterface/plugins/api

float eval_min;
float eval_max;
string mode;

array<string> bf_modes = {"lower", "higher"};
array<string> modes = {"back_right", "back_left", "front_right", "front_left"};

string wheel_type = "back_right";

void Main() {
    GetVariable("wheel_height_min_eval", eval_min);
    GetVariable("wheel_height_max_eval", eval_max);
    GetVariable("wheel_height_wheel_type", wheel_type);
    GetVariable("wheel_height_mode", mode);
    RegisterVariable("wheel_height_min_eval", 0);
    RegisterVariable("wheel_height_max_eval", 10000);
    RegisterVariable("wheel_height_wheel_type", "back_right");
    RegisterVariable("wheel_height_mode", "lower");
    RegisterVariable("wheel_height_trigger_index", 0);
    RegisterVariable("wheel_height_min_cp", 0);
    RegisterBruteforceEvaluation("Wheel Height", "Wheel Height", OnEvaluate, RenderEvalSettings);
}

void RenderEvalSettings()
{
    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Eval min", "wheel_height_min_eval");
    UI::InputTimeVar("Eval max", "wheel_height_max_eval");
    UI::Dummy(vec2(0, 5));
    GetVariable("wheel_height_wheel_type", wheel_type);
    GetVariable("wheel_height_mode", mode);
    if (UI::BeginCombo("Wheel", wheel_type)) {
        for (uint i = 0; i < modes.Length; i++)
        {
            string currentMode = modes[i];
            if (UI::Selectable(currentMode, wheel_type == currentMode))
            {
                wheel_type = currentMode;
                SetVariable("wheel_height_wheel_type", wheel_type);
            }
        }
                
        UI::EndCombo();
    }

    if (UI::BeginCombo("Mode", mode)) {
        for (uint i = 0; i < bf_modes.Length; i++)
        {
            string currentMode = bf_modes[i];
            if (UI::Selectable(currentMode, mode == currentMode))
            {
                mode = currentMode;
                SetVariable("wheel_height_mode", mode);
            }
        }
                
        UI::EndCombo();
    }

    UI::Dummy(vec2(0, 5));
    UI::InputFloatVar("Min speed", "bf_condition_speed", 10);
    UI::InputIntVar("Min CP collected", "wheel_height_min_cp", 1);
    UI::InputIntVar("Trigger index (0 to disable)", "wheel_height_trigger_index", 1);
    Trigger3D trigger = GetTriggerVar();
    if (trigger.Size.x != -1) {
        vec3 pos2 = trigger.Position + trigger.Size;
        UI::TextDimmed("The car must be in the trigger of coordinates: ");
        UI::TextDimmed("" + trigger.Position.ToString() + " " + pos2.ToString());
    }

}

float best = -1;
float current = -1;
int time = -1;
BFEvaluationResponse@ OnEvaluate(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int raceTime = simManager.RaceTime;

    auto resp = BFEvaluationResponse();
    if (info.Phase == BFPhase::Initial) {
        if (eval_min <= raceTime and raceTime <= eval_max and is_better(simManager)) {
            best = current;
            time = raceTime;
        }
        if (raceTime == eval_max) {
            print("best at " + time + ": " + Text::FormatFloat(best, "", 0, 15));
        }
    } else if (info.Phase == BFPhase::Search) {
        if (eval_min <= raceTime and raceTime <= eval_max and is_better(simManager)) {
            resp.Decision = BFEvaluationDecision::Accept;
            resp.ResultFileStartContent = "#Found better Wheel Height at " + Time::Format(raceTime) + ": " + Text::FormatFloat(best, "", 0, 15);
        }
        if (eval_max <= raceTime) {
            if (resp.Decision != BFEvaluationDecision::Accept) {
                resp.Decision = BFEvaluationDecision::Reject;
            }
        }
    }

    return resp;
}

bool is_better(SimulationManager@ sim_manager) {

    auto state = sim_manager.Dyna.CurrentState;
    auto pos = state.Location.Position;

    float kmhspeed;
    GetVariable("bf_condition_speed", kmhspeed);

    if (Norm(state.LinearSpeed) * 3.6 < kmhspeed) {
        return false;
    }

    if (GetD("wheel_height_trigger_index") > 0 && !IsInTrigger(pos)) {
        return false;
    }

    int cpCount = int(sim_manager.PlayerInfo.CurCheckpointCount);
    if (cpCount < GetD("wheel_height_min_cp")) {
        return false;
    }

    auto savedState = sim_manager.SaveState();
    auto wheels = savedState.Wheels;

    float yaw, pitch, roll;
    state.Location.Rotation.GetYawPitchRoll(yaw, pitch, roll);

    if (wheel_type == "back_right"){
        current = rotate(roll, yaw, pitch, wheels.BackRight.OffsetFromVehicle)[1] + pos[1];
    }
    else if (wheel_type == "back_left"){
        current = rotate(roll, yaw, pitch, wheels.BackLeft.OffsetFromVehicle)[1] + pos[1];
    }
    else if (wheel_type == "front_right"){
        current = rotate(roll, yaw, pitch, wheels.FrontRight.OffsetFromVehicle)[1] + pos[1];
    }
    else if (wheel_type == "front_left"){
        current = rotate(roll, yaw, pitch, wheels.FrontLeft.OffsetFromVehicle)[1] + pos[1];
    }
    else {
        print("BUG DETECTED");
    }

    return best == -1 or (mode == "lower" ? current < best : current > best);
}

bool IsInTrigger(vec3& pos) {
    auto trigger = GetTriggerVar();
    return trigger.ContainsPoint(pos);
}

Trigger3D GetTriggerVar() {
    uint triggerIndex = int(GetD("wheel_height_trigger_index"));
    return GetTriggerByIndex(triggerIndex-1);
}

float Norm(vec3& vec) {
    return Math::Sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
}

vec3 PointFromSavedVar(string pt)
{
    array<string> splits = pt.Split(" ");
    auto out_vec = vec3(Text::ParseFloat(splits[0]), Text::ParseFloat(splits[1]), Text::ParseFloat(splits[2]));
    return out_vec;
}

double GetD(string& str) {
    return GetVariableDouble(str);
}

vec3 rotate(float yaw, float pitch, float roll, vec3 points) {

    float cosa = Math::Cos(yaw);
    float sina = Math::Sin(yaw);

    float cosb = Math::Cos(pitch);
    float sinb = Math::Sin(pitch);

    float cosc = Math::Cos(roll);
    float sinc = Math::Sin(roll);

    float Axx = cosa*cosb;
    float Axy = cosa*sinb*sinc - sina*cosc;
    float Axz = cosa*sinb*cosc + sina*sinc;

    float Ayx = sina*cosb;
    float Ayy = sina*sinb*sinc + cosa*cosc;
    float Ayz = sina*sinb*cosc - cosa*sinc;

    float Azx = -sinb;
    float Azy = cosb*sinc;
    float Azz = cosb*cosc;

    float px = points[0];
    float py = points[1];
    float pz = points[2];

    points[0] = Axx*px + Axy*py + Axz*pz;
    points[1] = Ayx*px + Ayy*py + Ayz*pz;
    points[2] = Azx*px + Azy*py + Azz*pz;

    return points;
}

void OnRunStep(SimulationManager@ simManager)
{
    // THE FOLLOWING CODE HERE IS 100% IGNORABLE, ITS ONLY FOR DEBUGGING

    'if (simManager.RaceTime%1000 == 0 and simManager.RaceTime > 0) {
        auto state = simManager.Dyna.CurrentState;
        auto pos = state.Location.Position;

        auto savedState = simManager.SaveState();

        auto wheels = savedState.Wheels;

        float yaw, pitch, roll;
        state.Location.Rotation.GetYawPitchRoll(yaw, pitch, roll);

        //log("offset: " + Text::FormatFloat(wheels.FrontRight.OffsetFromVehicle[0], "", 0, 15));
        log("back-right wheel height: " + Text::FormatFloat(rotate(roll, yaw, pitch, wheels.BackRight.OffsetFromVehicle)[1] + pos[1], "", 0, 15));
        log("pos: " + Text::FormatFloat(pos[1], "", 0, 15));
        log("X velo: " + Text::FormatFloat(state.LinearSpeed[0], "", 0, 15));
    }';
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    GetVariable("wheel_height_min_eval", eval_min);
    GetVariable("wheel_height_max_eval", eval_max);
    GetVariable("wheel_height_wheel_type", wheel_type);
    GetVariable("wheel_height_mode", mode);
    best = -1;
    current = -1;
    time = -1;
}

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
}

void OnSimulationEnd(SimulationManager@ simManager, SimulationResult result)
{
}

void OnCheckpointCountChanged(SimulationManager@ simManager, int count, int target)
{
}

void OnLapCountChanged(SimulationManager@ simManager, int count, int target)
{
}

void Render()
{
}

void OnDisabled()
{
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "Wheel_height";
    info.Author = "Jsap";
    info.Version = "v1.0.0";
    info.Description = "Bruteforce script for height of a specific wheel";
    return info;
}
