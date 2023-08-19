// Documentation available at https://donadigo.com/tminterface/plugins/api

int eval_min;
int eval_max;
string point_raw;
vec3 any_point;
array<float> p_points = {0,0,0};

void RenderEvalSettings()
{
    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Eval min", "any_wheel_point_min_eval");
    UI::InputTimeVar("Eval max", "any_wheel_point_max_eval");

    UI::Dummy(vec2(0, 5));
    UI::DragFloat3Var("Point", "any_wheel_point_point");
    GetVariable("any_wheel_point_point", point_raw);
    any_point = PointFromSavedVar(point_raw);
    if (UI::Button("copy point")) {
        auto cam = GetCurrentCamera();
        if (@cam != null) {
            SetVariable("any_wheel_point_point", cam.Location.Position.ToString());
        }
    }
    
    UI::Dummy(vec2(0, 5));
    UI::Text("Min speed:");
    UI::InputFloatVar("", "bf_condition_speed", 10);
    UI::Text("Min cp:");
    UI::InputIntVar("Min CP collected", "any_wheel_min_cp", 1);

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
            //resp.ResultFileStartContent = "Found better wheel pos " + Time::Format(raceTime) + ": " + Text::FormatFloat(best, "", 0, 15);
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

    int cpCount = int(sim_manager.PlayerInfo.CurCheckpointCount);
    if (cpCount < GetD("any_wheel_min_cp")) {
        return false;
    }

    auto savedState = sim_manager.SaveState();
    auto wheels = savedState.Wheels;

    current = 999999999;

    float yaw, pitch, roll;
    state.Location.Rotation.GetYawPitchRoll(yaw, pitch, roll);

    float wheel_x;
    float wheel_y;
    float wheel_z;

    for (int i = 0; i < 4; i++) {
        switch(i)
        {
            case 0:
                wheel_x = rotate(roll, yaw, pitch, wheels.BackRight.OffsetFromVehicle)[0] + pos[0];
                wheel_y = rotate(roll, yaw, pitch, wheels.BackRight.OffsetFromVehicle)[1] + pos[1];
                wheel_z = rotate(roll, yaw, pitch, wheels.BackRight.OffsetFromVehicle)[2] + pos[2];
                break;
            
            case 1:
                wheel_x = rotate(roll, yaw, pitch, wheels.BackLeft.OffsetFromVehicle)[0] + pos[0];
                wheel_y = rotate(roll, yaw, pitch, wheels.BackLeft.OffsetFromVehicle)[1] + pos[1];
                wheel_z = rotate(roll, yaw, pitch, wheels.BackLeft.OffsetFromVehicle)[2] + pos[2];
                break;
            
            case 2:
                wheel_x = rotate(roll, yaw, pitch, wheels.FrontRight.OffsetFromVehicle)[0] + pos[0];
                wheel_y = rotate(roll, yaw, pitch, wheels.FrontRight.OffsetFromVehicle)[1] + pos[1];
                wheel_z = rotate(roll, yaw, pitch, wheels.FrontRight.OffsetFromVehicle)[2] + pos[2];
                break;
            
            case 3:
                wheel_x = rotate(roll, yaw, pitch, wheels.FrontLeft.OffsetFromVehicle)[0] + pos[0];
                wheel_y = rotate(roll, yaw, pitch, wheels.FrontLeft.OffsetFromVehicle)[1] + pos[1];
                wheel_z = rotate(roll, yaw, pitch, wheels.FrontLeft.OffsetFromVehicle)[2] + pos[2];
                break;
        
        }
        vec3 wheel_pos = vec3(wheel_x, wheel_y, wheel_z);

        float dist = Math::Distance(wheel_pos, any_point);

        if (dist < current){
            current = dist;
        }
    }

    return best == -1 or current < best;
}

void Main() {
    GetVariable("any_wheel_point_min_eval", eval_min);
    GetVariable("any_wheel_point_max_eval", eval_max);
    GetVariable("any_wheel_point_point", point_raw);
    RegisterVariable("any_wheel_point_min_eval", 0);
    RegisterVariable("any_wheel_point_max_eval", 10000);
    RegisterVariable("any_wheel_point_point", "0 0 0");
    RegisterVariable("any_wheel_min_cp", 0);
    RegisterBruteforceEvaluation("Any wheel point", "Any wheel point", OnEvaluate, RenderEvalSettings);
}

vec3 PointFromSavedVar(string pt)
{
    array<string> splits = pt.Split(" ");
    auto out_vec = vec3(Text::ParseFloat(splits[0]), Text::ParseFloat(splits[1]), Text::ParseFloat(splits[2]));
    return out_vec;
}

float Norm(vec3& vec) {
    return Math::Sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
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
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    GetVariable("any_wheel_point_min_eval", eval_min);
    GetVariable("any_wheel_point_max_eval", eval_max);
    GetVariable("any_wheel_point_point", point_raw);
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
    info.Name = "any wheel point";
    info.Author = "Jsap";
    info.Version = "v1.0.0";
    info.Description = "Bruteforce script for point with any wheel";
    return info;
}
