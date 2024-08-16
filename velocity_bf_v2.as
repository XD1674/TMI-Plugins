// Documentation available at https://donadigo.com/tminterface/plugins/api

float eval_min;
float eval_max;
array<string> axis_settings = {"don't bf", "lower", "don't bf"};
array<int> axis_settings_numerical = {1, 1, 1};

array<string> modes = {"don't bf", "lower", "higher", "bf for 0"};

void RenderEvalSettings()
{
    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Eval min", "velocity_jsap_min_eval");
    UI::InputTimeVar("Eval max", "velocity_jsap_max_eval");
    UI::Dummy(vec2(0, 5));
    GetVariable("velocity_jsap_axis_x", axis_settings[0]);
    GetVariable("velocity_jsap_axis_y", axis_settings[1]);
    GetVariable("velocity_jsap_axis_z", axis_settings[2]);

    UI::Text("X coordinate increases when you go towards blue sign");
    UI::Text("Y coordinate increases when going up");
    UI::Text("Z increases when you look towards blue sign and go right");

    UI::Dummy(vec2(0, 5));
    //UI:SameLine();

    if (UI::BeginCombo("X Velocity", axis_settings[0])) {
        for (uint i = 0; i < modes.get_Length(); i++)
        {
            string currentMode = modes[i];
            if (UI::Selectable(currentMode, axis_settings[0] == currentMode))
            {
                axis_settings[0] = currentMode;
                SetVariable("velocity_jsap_axis_x", axis_settings[0]);
            }
        }
                
        UI::EndCombo();
    }

    if (UI::BeginCombo("Y Velocity", axis_settings[1])) {
        for (uint i = 0; i < modes.get_Length(); i++)
        {
            string currentMode = modes[i];
            if (UI::Selectable(currentMode, axis_settings[1] == currentMode))
            {
                axis_settings[1] = currentMode;
                SetVariable("velocity_jsap_axis_y", axis_settings[1]);
            }
        }
                
        UI::EndCombo();
    }

    if (UI::BeginCombo("Z Velocity", axis_settings[2])) {
        for (uint i = 0; i < modes.get_Length(); i++)
        {
            string currentMode = modes[i];
            if (UI::Selectable(currentMode, axis_settings[2] == currentMode))
            {
                axis_settings[2] = currentMode;
                SetVariable("velocity_jsap_axis_z", axis_settings[2]);
            }
        }
                
        UI::EndCombo();
    }

    UI::Dummy(vec2(0, 5));
    UI::InputFloatVar("Min speed", "bf_condition_speed", 10);
    UI::InputIntVar("Min CP collected", "velocity_jsap_min_cp", 1);
    UI::InputIntVar("Trigger index (0 to disable)", "jsap_trigger_index", 1);
    Trigger3D trigger = GetTriggerVar();
    if (trigger.Size.x != -1) {
        vec3 pos2 = trigger.Position + trigger.Size;
        UI::TextDimmed("The car must be in the trigger of coordinates: ");
        UI::TextDimmed("" + trigger.Position.ToString() + " " + pos2.ToString());
    }

}

array<float> best = {-1, -1, -1};
array<float> current = {-1, -1, -1};
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
            print("base at " + time + " Iteration:" + info.Iterations);
            if (axis_settings[0] != "don't bf") {
                if (axis_settings[0] == "bf for 0"){
                    print("X Velocity: " + Text::FormatFloat(best[0]*3.6*axis_settings_numerical[0], "", 0, 15) + "    bf-ing for 0  (negative sign might be incorrect here)");
                }
                else {
                    print("X Velocity: " + Text::FormatFloat(best[0]*3.6*axis_settings_numerical[0], "", 0, 15) + "    bf-ing for " + axis_settings[0]);
                }
            }
            if (axis_settings[1] != "don't bf") {
                if (axis_settings[1] == "bf for 0"){
                    print("Y Velocity: " + Text::FormatFloat(best[1]*3.6*axis_settings_numerical[1], "", 0, 15) + "    bf-ing for 0  (negative sign might be incorrect here)");
                }
                else {
                    print("Y Velocity: " + Text::FormatFloat(best[1]*3.6*axis_settings_numerical[1], "", 0, 15) + "    bf-ing for " + axis_settings[1]);
                }
            }
            if (axis_settings[2] != "don't bf") {
                if (axis_settings[2] == "bf for 0"){
                    print("Z Velocity: " + Text::FormatFloat(best[2]*3.6*axis_settings_numerical[2], "", 0, 15) + "    bf-ing for 0  (negative sign might be incorrect here)");
                }
                else {
                    print("Z Velocity: " + Text::FormatFloat(best[2]*3.6*axis_settings_numerical[2], "", 0, 15) + "    bf-ing for " + axis_settings[2]);
                }
            }
            print(Text::FormatFloat(SumArrayElements(best)*3.6, "", 0, 15));
        }
    } else if (info.Phase == BFPhase::Search) { 
        if (eval_min <= raceTime and raceTime <= eval_max and is_better(simManager)) { 
            resp.Decision = BFEvaluationDecision::Accept;
            print("new improvement found", Severity::Success);
            //resp.ResultFileStartContent = "#new imporvement found" + Time::Format(raceTime); 
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

    auto state_velocity = state.LinearSpeed;

    float kmhspeed;
    GetVariable("bf_condition_speed", kmhspeed);

    if (Norm(state_velocity) * 3.6 < kmhspeed) {
        return false;
    }

    int cpCount = int(sim_manager.PlayerInfo.CurCheckpointCount);
    if (cpCount < GetD("velocity_jsap_min_cp")) {
        return false;
    }

    if (GetD("jsap_trigger_index") > 0 && !IsInTrigger(pos)) {
        return false;
    }

    for (int l = 0; l < 3; l++){
        if (axis_settings[l] == "bf for 0") {
            current[l] = Math::Abs(state_velocity[l]) < 1000/3.6 ? -Math::Abs(state_velocity[l]) : -1000/3.6;
        }
        else {
            current[l] = state_velocity[l] < 1000/3.6 ? state_velocity[l]*axis_settings_numerical[l] : 1000/3.6*axis_settings_numerical[l];
            current[l] = state_velocity[l] > -1000/3.6 ? current[l] : -1000/3.6*axis_settings_numerical[l];
        }
    }

    return time == -1 or SumArrayElements(current) > SumArrayElements(best);
}

void Main() {
    GetVariable("velocity_jsap_min_eval", eval_min);
    GetVariable("velocity_jsap_max_eval", eval_max);
    GetVariable("velocity_jsap_axis_x", axis_settings[0]);
    GetVariable("velocity_jsap_axis_y", axis_settings[1]);
    GetVariable("velocity_jsap_axis_z", axis_settings[2]);
    RegisterVariable("velocity_jsap_min_eval", 0);
    RegisterVariable("velocity_jsap_max_eval", 10000);
    RegisterVariable("velocity_jsap_axis_x", "don't bf");
    RegisterVariable("velocity_jsap_axis_y", "lower");
    RegisterVariable("velocity_jsap_axis_z", "don't bf");
    RegisterVariable("velocity_jsap_min_cp", 0);
    RegisterVariable("jsap_trigger_index", 0);
    RegisterBruteforceEvaluation("Velocity", "Velocity", OnEvaluate, RenderEvalSettings);
}

void OnRunStep(SimulationManager@ simManager)
{
}

float Norm(vec3& vec) {
    return Math::Sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
}

double GetD(string& str) {
    return GetVariableDouble(str);
}

Trigger3D GetTriggerVar() {
    uint triggerIndex = int(GetD("jsap_trigger_index"));
    return GetTriggerByIndex(triggerIndex-1);
}

bool IsInTrigger(vec3& pos) {
    auto trigger = GetTriggerVar();
    return trigger.ContainsPoint(pos);
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    best = {-1, -1, -1};
    current = {-1, -1, -1};
    time = -1;
    GetVariable("velocity_jsap_min_eval", eval_min);
    GetVariable("velocity_jsap_max_eval", eval_max);
    GetVariable("velocity_jsap_axis_x", axis_settings[0]);
    GetVariable("velocity_jsap_axis_y", axis_settings[1]);
    GetVariable("velocity_jsap_axis_z", axis_settings[2]);
    for (int i = 0; i < 3; i++){
        if (axis_settings[i] == "don't bf"){
            axis_settings_numerical[i] = 0;
        }
        else if (axis_settings[i] == "lower"){
            axis_settings_numerical[i] = -1;
        } 
        else if (axis_settings[i] == "higher" or axis_settings[i] == "bf for 0"){
            axis_settings_numerical[i] = 1;
        }
    }
}

float SumArrayElements(array<float> some_array){
    float sum = 0;
    for (int k = 0; k < int(some_array.Length); k++){
        sum += some_array[k];
    }
    return sum;
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
    info.Name = "velocity_bf";
    info.Author = "Jsap";
    info.Version = "v1.1.0";
    info.Description = "bf for velocity in a given axis";
    return info;
}