//
//  ColorPicking.mm
//  aluminum
//
//  Created by Kyle Reese Almryde on 11/4/14.
//  Copyright (c) 2014 Kyle Reese Almryde. All rights reserved.
//

#import <Aluminum/RendererOSX.h>
#import <Aluminum/MeshUtils.hpp>
#import <Aluminum/MeshBuffer.hpp>
#import <Aluminum/MeshData.hpp>
#import <Aluminum/Shapes.hpp>
#import <Aluminum/Program.hpp>
#import <Aluminum/Camera.hpp>
#import <Aluminum/Behavior.hpp>
#import <Aluminum/ResourceHandler.h>

using namespace glm;
using namespace aluminum;

class ColorPicking : public RendererOSX {
public:
    
    Camera camera;
    Program shader, phong;
    MeshBuffer cubeMB, mb[3];
    Behavior rotateBehavior;
    ResourceHandler rh;
    
    //modelview and projection matrices
    glm::mat4 M, V, P, fView, pModel = mat4(1);  // View*Projection Matrix and Backup matrix
    
    //box positions
    vec3 box_positions[3]={
        glm::vec3(-1.5, 0.5, 0.0),
        glm::vec3( 0.0, 0.5, 1.0),
        glm::vec3( 1.5, 0.5, 0.0)
    };
    vec3 obj_positions[3]={
        glm::vec3(-1.5,0.0, 0.0),
        glm::vec3( 0.0,0.0, 1.0),
        glm::vec3( 1.5,0.0, 0.0)
    };
    
    mat4 box_model[3] = {
        mat4(1),
        glm::rotate(mat4(1), 90.f, vec3(0.,1.,0.)),
        glm::rotate(mat4(1), 2.f, vec3(0.,1.,0.))
    };
    
    vec3 box_color[3] = {
        vec3(1.,0.,0.),
        vec3(0.,1.,0.),
        vec3(0.,0.,1.)
    };
    
    vec3 lightPos = vec3(0.0,0.0,10.0);
    vec3 specular = vec3(1.0,1.0,1.0);
    vec3 ambient = vec3(0.0,0.0,0.3);
    
    glm::vec3 objPt, diff;
    glm::vec3 localObjPt, worldObjPt;
    
    int posLoc = 0,
    normalLoc = 1;
    
    //selected box index
    int selected_box=-1;
    int which = 0;
    
    float rX = radians(2.0);
    float rY = radians(2.0);
    float winZ=0;
    float offset = 2.5f;
    
    
    virtual void onCreate() {
        rh.loadProgram(shader, "cube", posLoc, -1, -1, -1);
        rh.loadProgram(phong, "phong", posLoc, normalLoc, -1, -1);
        
        MeshData modelMesh[3];
        
        rh.loadObjIntoMesh(modelMesh[0], "dragon.obj", 1.5);
        rh.loadObjIntoMesh(modelMesh[1], "bunny.obj", .5);
        rh.loadObjIntoMesh(modelMesh[2], "venusl.obj", 0.0005);  // She is huge...
        
        cubeMB.init(MeshUtils::makeCube(0.5), posLoc, -1, -1, -1);
        mb[0].init(modelMesh[0], posLoc, normalLoc, -1, -1);
        mb[1].init(modelMesh[1], posLoc, normalLoc, -1, -1);
        mb[2].init(modelMesh[2], posLoc, normalLoc, -1, -1);
        
        
        //set the camera position
        camera = Camera(radians(60.0), (float)width / (float)height, 0.01, 100.0).translateZ(-5.f);
        rotateBehavior = Behavior(now()).delay(1000).length(10000).range(M_PI * 2.0).looping(true).repeats(-1);
        
        // Set a "Flat" view
        fView = camera.view;
        
        for (int i = 0; i<3; i++){
            box_model[i] = glm::translate(mat4(1), box_positions[i]);
        }
        
        glViewport(0, 0, width, height);
        
        //enable depth testing
        glEnable(GL_DEPTH_TEST);
        
        cout<<"Initialization successfull"<<endl;
    }
    
    
    void drawCube(vec3 color) {
        
        shader.bind();
        {
            glUniformMatrix4fv(shader.uniform("MVP"), 1, 0, ptr(P * V * M));
            glUniform3fv(shader.uniform("vColor"),1, ptr(color));
            cubeMB.draw();
        }
        shader.bind();
    }
    
    
    void drawPhong(vec3 diffuse, int index) {
        
        float total = rotateBehavior.tick(now()).total();
        M = glm::rotate(M, total, vec3(0.0f,1.0f,0.0f));
        
        phong.bind();
        {
            glUniformMatrix4fv(phong.uniform("model"), 1, 0, ptr(M));
            glUniformMatrix4fv(phong.uniform("view"), 1, 0, ptr(V));
            glUniformMatrix4fv(phong.uniform("proj"), 1, 0, ptr(P));
            
            glUniform3f(phong.uniform("lightPos"), 0.0, 0.0, 10.0);
            glUniform3fv(phong.uniform("ambient"), 1, ptr(ambient));
            glUniform3fv(phong.uniform("diffuse"), 1, ptr(diffuse));
            glUniform3fv(phong.uniform("specular"), 1, ptr(specular));
            
            mb[index].draw();
            
        }
        phong.unbind();
    }
    
    
    
    virtual void onFrame() {
        handleMouse();
        
        if (camera.isTransformed) {
            printf("Camera is Transformed!\n");
            camera.transform();
        }
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        
        vec3 color;
        for(int i = 0; i < 3; i++) {
            if (selected_box == i) {
                M = pModel;
                V = fView;
                P = camera.projection;
                color = vec3(0,1,1);
            } else {
                M = box_model[i];
                V = camera.view;
                P = camera.projection;
                color = box_color[i];
            }
            if (which > 0)
                drawPhong(color, i);
            else
                drawCube(color);
        }
    }
    
    
    virtual void onReshape() {
        //set the viewport size
        glViewport (0, 0, (GLsizei) width, (GLsizei) height);
        camera.perspective(radians(60.0), (float)width / (float)height, 0.01, 100.0);
    }
    
    
    bool getSelection() {
        GLubyte pixel[4];
        //read color value at the clicked position form the color buffer
        glReadPixels( mouseX, mouseY, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
        printf("%d %d %d %d\n", pixel[0], pixel[1], pixel[2], pixel[3]);
        if (pixel[0] >= 90 && pixel[1] < 80 && pixel[2] < 80) {
            selected_box = 0;
        }
        
        if (pixel[0] < 80 && pixel[1] >= 90 && pixel[2] < 80) {
            selected_box = 1;
            printf("\tMissed box: %d\n\n", 0);
        }
        
        if (pixel[0] < 80 && pixel[1] < 80 && pixel[2] >= 90) {
            selected_box = 2;
            printf("\tMissed box: %d\n\n", 1);
        }
        
        if(selected_box!=-1) {
            printf("\tPicked box: %d\n\n", selected_box);
            return true;
        }
        
        return false;
    }
    
    
    
    
    virtual void handleMouse() {
        glm::project(vec3(mouseX,mouseY,0), fView, camera.projection, vec4(0,0,width, height));
        
        //        Raw screen coordinates projected onto the view plane
        glm::vec3 screenObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), fView, camera.projection, vec4(0,0,width, height));
        glm::vec3 screenObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), fView, camera.projection, vec4(0,0,width, height));
        diff = glm::normalize(screenObjPt_F - screenObjPt_N);
        
        //        XXX "World" Coordinates...View matrix/camera space
        //        glm::vec3 worldObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), camera.view, camera.projection, vec4(0,0,width, height));
        //        glm::vec3 worldObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), camera.view, camera.projection, vec4(0,0,width, height));
        //        diff = glm::normalize(worldObjPt_F - worldObjPt_N);
        
        //        XXX Local coordinates...Model*View, still follows the camera...
        //        glm::vec3 localObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), camera.view*box_model[selected_box], camera.projection, vec4(0,0,width, height));
        //        glm::vec3 localObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), camera.view*box_model[selected_box], camera.projection, vec4(0,0,width, height));
        //        diff = glm::normalize(localObjPt_F - localObjPt_N);
        
        //        glm::vec3 objPt_N = glm::unProject(vec3(mouseX,mouseY,0.), fView*box_model[selected_box], camera.projection, vec4(0,0,width, height));
        //        glm::vec3 objPt_F = glm::unProject(vec3(mouseX,mouseY,1.), fView*box_model[selected_box], camera.projection, vec4(0,0,width, height));
        //        diff = glm::normalize(objPt_F - objPt_N);
        
        
        if (isMoving && selected_box!= -1) {
            
            printf("We're MOVING!!\n");
            pModel = glm::translate(fView, vec3(diff.x*offset, diff.y*offset,-3.));
        }
        
        if (isPressing)
        {
            // If we pick an object for the first time
            if (selected_box < 0 && getSelection()) {
                printf("\tSELECTED!!\n");
                // This snaps the object to the location of the mouse
                pModel = glm::translate(fView, vec3(diff.x*offset, diff.y*offset,-3.));
                
                // If a cube is selected, and we "pick it" again, deselect the cube and place .. the
            } else if (selected_box != -1 && getSelection()){
                printf("\tDESELECTED!!\n");
                box_model[selected_box] = glm::translate(mat4(1), which < 1? box_positions[selected_box]: obj_positions[selected_box]);
                selected_box = -1;
            }
        }
        
        
        isDragging = false;
        isMoving = false;
        isPressing = false;
    }
    
    
    virtual void keyDown(char key) {
        
        switch(key) {
            case kVK_Space :
                camera.resetVectors();
                camera.translateZ(-5.f);
                selected_box = -1;
                
                if(which < 1) {
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), box_positions[i]);
                    }
                    
                } else{
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), obj_positions[i]);
                    }
                    
                }
                break;
            case kVK_ANSI_W :
                camera.translate(vec3(0,0,0.2));
                break;
            case kVK_ANSI_S :
                camera.translate(vec3(0,0,-0.2));
                break;
            case kVK_ANSI_A :
                camera.rotate(vec3(0.0,rY,0.0));
                break;
            case kVK_ANSI_D :
                camera.rotate(vec3(0.0,-rY,0.0));
                break;
            case kVK_ANSI_Q :
                camera.rotate(vec3(rX,0.0,0.0));
                break;
            case kVK_ANSI_E :
                camera.rotate(vec3(-rX,0.0,0.0));
                break;
            case kVK_UpArrow:
                camera.printCameraInfo();
                if(which < 1) {
                    which++;
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), obj_positions[i]);
                    }
                    
                } else{
                    which--;
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), box_positions[i]);
                    }
                    
                }
                break;
                
            default:
                break;
        }
    }
    
};

int main() {
    return ColorPicking().start("aluminum::ColorPicking", 100, 100, 400, 400);
}